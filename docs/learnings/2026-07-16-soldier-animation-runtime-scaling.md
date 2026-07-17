# Soldier Animation Runtime Scaling Learnings

**Date:** 2026-07-16  
**Status:** Resolved for the shared soldier playback path

## Context

The soldier animation redesign went through several visually similar problems:
missing attack motion, inconsistent character identity, cropped frame bleed,
overly fast playback, excessive body movement, and finally repeated shrinking
and enlarging in the iOS Simulator.

The source Infantry GIF eventually looked stable while the same frames still
pulsed in the running game. That difference was the decisive clue: the remaining
defect was no longer in the PNG assets.

## Iteration Summary

1. Audited walk, attack, and hit playback for every soldier type.
2. Corrected action routing and replaced procedural-only feedback with authored
   action frames.
3. Regenerated inconsistent artwork, fixed frame boundaries, and aligned each
   action to a shared identity and baseline.
4. Slowed playback and refined Archer and Infantry movement.
5. Stabilized source-frame scale and verified slowed GIF previews.
6. Reproduced the remaining pulse in a real `SKView` and traced live node
   geometry instead of modifying the art again.

## Root Cause

The installed executable and `Assets.car` matched the current checkout, and all
30 compiled Infantry renditions were `128x128`. Runtime sampling also showed
that `root`, `motionRoot`, and body scales stayed at `1`.

The value that changed was `SKSpriteNode.size`:

- fitted battlefield size: approximately `111.05x111.05`
- intrinsic texture size: `128x128`

On the observed iOS 26.5 Simulator runtime,
`SKAction.setTexture(_:resize: false)` still restored the texture's intrinsic
size at animation frame boundaries. The next `BattleScene` update fitted the
sprite back to `111.05`, producing a visible `111.05 -> 128 -> 111.05` pulse
throughout walk and attack playback.

An isolated SpriteKit test confirmed that direct `sprite.texture` assignment
preserved the fitted size while `SKAction.setTexture` did not.

## Fix

[BattleScene](../../Pyxis/BattleScene.swift) now swaps animation textures through
direct assignment inside the existing keyed action sequence. Frame order,
timing, interruption, walk resumption, and asset selection remain unchanged.

[SoldierRuntimeGeometryTests](../../PyxisTests/SoldierRuntimeGeometryTests.swift)
presents a real `SKView`, runs Infantry walk and attack actions, samples the body
size across rendered frames, and fails if width or height changes.

## Why This Took Many Iterations

- Multiple asset and runtime defects produced the same broad symptom: the
  soldier looked inconsistent while animating.
- Static contact sheets and GIFs validated source artwork but not SpriteKit's
  compiled texture and node behavior.
- Repeated asset changes could not fix a size mutation introduced after the
  assets entered the runtime.
- Simulator cache concerns were plausible, but build identity needed to be
  proven rather than repeatedly cleaned.
- Narrow Swift Testing selectors sometimes executed zero tests, so successful
  command status alone was not reliable evidence.

## Better Debugging Sequence

For future soldier animation defects:

1. Reproduce with one soldier, one action, and no overlapping units.
2. Check frame order, dimensions, alpha bounds, baseline, and slowed source GIF.
3. If the source preview is correct, stop editing artwork.
4. Compare the installed executable and `Assets.car` with the intended build.
5. Inspect compiled rendition dimensions and runtime `SKTexture` properties.
6. Sample `root`, `motionRoot`, body scale, body size, and texture identity on
   actual render frames.
7. Isolate suspicious SpriteKit APIs in a minimal rendered test.
8. Add a regression test that reproduces the user-visible runtime boundary.
9. Confirm the test execution count, then launch a fresh normal simulator build.

## Durable Rules

- Treat source assets, compiled assets, installed app, texture playback, node
  geometry, and final rendering as separate debugging boundaries.
- When a source GIF and the simulator disagree, runtime evidence takes priority.
- For fitted soldier sprites, texture changes must not be allowed to own or
  mutate node geometry.
- Keep authored motion inside frames; keep runtime scale stable.
- Regenerate assets only when image evidence identifies an image defect.
- Verify one soldier end to end before applying the same approach to all types.
