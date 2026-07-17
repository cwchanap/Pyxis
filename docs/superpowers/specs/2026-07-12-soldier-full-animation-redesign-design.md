# Soldier Full Animation Redesign

**Date:** 2026-07-12  
**Status:** Implemented

## Summary

Regenerate the complete walk, attack, and hit animation set for all five soldier
types. Each soldier will use one canonical identity across all thirty frames,
with stable scale, baseline, equipment, rendering style, and neutral transition
poses. Runtime playback will use authored full-canvas frames with readable,
action-specific pacing and no duplicate procedural body effects.

This specification expands and supersedes the asset and playback scope in
`2026-07-09-soldier-action-animation-redesign-design.md`, which intentionally
left the existing walk frames unchanged.

## Problem

The current catalog mixes independently generated frame sets:

- Archer attack and hit now share an approved detailed identity, but archer walk
  is smaller, less detailed, and contains clipped bow or arrow fragments.
- Infantry, cavalry, mage, and siege visibly change appearance between walk,
  attack, and hit.
- Existing non-archer sheets contain neighboring-frame fragments, inconsistent
  scale, and oversized action effects.
- Uniform transient frame timing makes anticipation, contact, and recovery read
  less naturally than the artwork requires.

Replacing only one action at a time would preserve these transition pops. Each
soldier must therefore be authored, reviewed, and installed as a complete trio.

## Goals

- Replace all 150 soldier frames: five types, three actions, ten frames each.
- Establish one canonical face, body, costume, palette, equipment design,
  outline weight, lighting direction, and render quality for each soldier.
- Make walk movement visible without whole-body bouncing or scale pumping.
- Give attack animations clear mechanics, anticipation, commitment,
  follow-through, and recovery.
- Give hit animations readable facial expressions and defensive posture changes
  while feet, hooves, and wheels remain grounded.
- Eliminate adjacent-frame bleed, clipped equipment, detached fragments, and
  action-to-action appearance changes.
- Use readable non-uniform attack and hit pacing at battlefield scale.

## Non-Goals

- Do not change combat damage, attack speed, movement speed, targeting, range,
  HP, spawning, lanes, or battle layout.
- Do not add new gameplay controls, projectiles, physics, or hitboxes.
- Do not place slash arcs, impact stars, speed lines, auras, explosions, text,
  cast shadows, or decorative scenery inside soldier body frames.
- Do not refactor unrelated scenes or campaign/economy models.

## Scope And Rollout

The redesign replaces these stable asset names:

- `<type>-walk-01` through `<type>-walk-10`
- `<type>-attack-01` through `<type>-attack-10`
- `<type>-hit-01` through `<type>-hit-10`

Types are processed in this order:

1. Archer
2. Infantry
3. Cavalry
4. Mage
5. Siege

For each type, create and approve a canonical neutral identity, then generate all
three coordinated storyboards from that identity. Review the complete trio as
contact sheets and slowed GIFs before installing any of its frames. Until the
trio passes review and validation, runtime keeps that type on its current stable
fallback.

## Canonical Identities

Archer uses the approved attack and hit artwork as the primary identity
reference: green hood, face, leather layers, quiver, arrows, and the exact bow
shape, color, grip, string, and proportions.

For infantry, cavalry, mage, and siege, the existing walk set remains a semantic
reference for recognizable colors, equipment, and role. Those old frames are
not a rendering-quality reference. Their canonical redraw adopts the detail,
outline quality, material treatment, facial proportions, and polish of the
approved archer set.

Within a soldier's thirty frames, the following are invariant:

- face and hair
- body and head proportions
- costume pieces and colors
- weapon or mechanism construction
- outline weight and lighting direction
- apparent body scale and ground baseline
- battlefield-facing direction

## Shared Motion Contract

Every action uses ten row-major frames in a 5-by-2 storyboard. Frames one and ten
are neutral transition poses close enough to each other that loops and action
changes do not pop.

### Walk

- Use a clear alternating in-place step cycle.
- Move legs, arms, cloth, reins, wheels, or carried equipment naturally for the
  soldier type.
- Keep torso height and apparent body scale stable; do not translate the entire
  body back and forth.
- Keep feet, hooves, or wheels on one baseline with no sliding.
- Use secondary motion only where attached equipment naturally follows the
  primary movement.

### Attack

Frames follow this phase order:

1. Neutral
2. Initial anticipation
3. Peak wind-up
4. Commitment
5. Contact or release
6. Follow-through
7. Rebound
8. Recovery
9. Settle
10. Neutral

The body and weapon must communicate the action without an overlaid effect. The
lower body remains grounded unless a controlled step is intrinsic to the type.

### Hit

Frames show recognition, brace, peak recoil, held expression, rebound, and
controlled recovery. Facial expression and posture carry the reaction. The
character retains its weapon and equipment, and the whole sprite does not jump
or shrink.

## Type-Specific Motion

### Archer

- Walk: alternate planted steps while the torso and bow remain stable; allow
  restrained cape and quiver follow-through.
- Attack: settle the bow shoulder, extend the bow arm, raise the drawing elbow,
  draw to the cheek, release, recoil, and recover.
- Hit: collapse the shoulder and torso briefly with tightened eyes or a grimace,
  then recover while retaining the bow.

### Infantry

- Walk: alternate armored steps with restrained sword, shield, and plume motion.
- Attack: use a compact sword wind-up, planted front foot, weight transfer,
  diagonal strike, wrist and shoulder follow-through, and return behind shield.
- Hit: turn shield and torso toward impact, compress the stance, grimace, and
  regain guard.

### Cavalry

- Walk: use a controlled horse step cycle with rider hips and reins following
  the mount; no hopping or full-unit bobbing.
- Attack: lower and drive the lance while the horse braces and takes one
  controlled forward step.
- Hit: have the mount check its step while the rider absorbs impact through the
  seat and reins.

### Mage

- Walk: alternate small steps with robe and staff follow-through while the head
  and torso remain stable.
- Attack: plant the staff, gather with the free hand, direct the staff, and
  settle. A tiny staff-tip glow is allowed only if the pose reads without it.
- Hit: interrupt the casting posture, tighten the face, fold the free arm inward,
  and restore the staff-bearing stance.

### Siege

- Walk: rotate or shift wheels and operator limbs with the chassis grounded and
  level.
- Attack: brace, operate the mechanism, absorb mechanical recoil, and reset.
- Hit: use a short chassis jolt and operator brace followed by mechanical
  settling, without smoke or explosions.

## Storyboard And Frame Contract

- Source layout is a centered 5-column by 2-row grid of square cells.
- Frame order is row-major: one through five, then six through ten.
- Use flat `#ff00ff` for archer and flat `#00ff00` for other types.
- Reserve the outer eight percent of every cell for key color only.
- Keep the complete character and equipment inside its cell safety border.
- Slice the complete square cell with one identical transform for every frame.
- Output is exactly ten 128-by-128 RGBA PNGs per action.
- Output corners and at least four outer pixels are transparent.
- Ground-baseline variation may not exceed six output pixels; authored review
  applies a stricter expectation of no visible foot, hoof, or wheel bounce.
- Per-frame opaque density and height must remain within the existing validator
  thresholds, and adjacent frames must not be pixel-identical.

The pipeline rejects a complete action before replacing existing assets if any
frame fails. It never repairs a broken source by content-based crop or scaling.
Rigid source-cell translation is allowed only to correct layout placement while
preserving authored scale and pixels.

## Runtime Timing

Walk uses ten uniform 0.10-second frames for a 1.0-second loop.

Attack totals are:

- Infantry: 1.2 seconds
- Archer: 1.4 seconds
- Cavalry: 1.2 seconds
- Mage: 1.4 seconds
- Siege: 1.6 seconds

Attack frame weights are
`[1.10, 1.20, 1.30, 0.75, 0.70, 0.85, 1.00, 1.15, 1.10, 0.85]`.
The weights sum to ten and are normalized to the type's total duration. This
holds anticipation and recovery while moving more quickly through contact.

Hit lasts 0.9 seconds for every type. Hit frame weights are
`[0.90, 1.00, 1.10, 1.20, 1.20, 1.00, 0.95, 0.90, 0.90, 0.85]`, normalized to
the total duration so peak expression and posture remain readable.

Hit interrupts attack when both occur in one combat tick. A surviving soldier
returns to walk after the transient completes. A killed soldier remains visible
through the readable hit peak before the existing removal transition.

## Runtime Integration

`BattleScene` loads complete action-specific texture sets for approved soldier
types and displays the full 128-by-128 canvas using `SoldierAnimationGeometry`.
HP bars remain positioned from the logical body frame.

Add a per-frame action builder that applies the timing weights above instead of
using one uniform `SKAction.animate` duration for transient actions. Before a
transient starts, remove competing walk, attack, and hit texture actions.

After a soldier trio is approved, remove its procedural attack cue, body lunge,
hit flash, facial marks, and posture overlay. Unapproved types keep the stable
fallback until their complete trio is ready.

## Validation And Testing

Use TDD for runtime and pipeline behavior. Required gates per soldier are:

1. Canonical neutral identity review.
2. Contact-sheet review of all thirty frames.
3. Slowed GIF review of walk, attack, and hit.
4. Automated frame-count, dimensions, alpha, border, density, height, baseline,
   and adjacent-frame checks.
5. Focused `BattleSceneTests` for distinct textures, full-canvas geometry,
   timing, interruption, walk resumption, killed-soldier removal, and absence of
   procedural overlays.
6. Full `PyxisTests` and `PyxisUITests` with parallel testing disabled.
7. SwiftLint with a writable cache path and `git diff --check`.
8. Xcode DerivedData rebuild, simulator launch, and recorded runtime review for
   walk, attack, and hit.

An asset set is complete only when the generated previews, source frames,
compiled catalog, installed app, and simulator playback all show the same
approved art.
