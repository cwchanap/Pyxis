# Task 11 report: canonical Forged Battle correction

## Scope

Finalized the existing Task 11 Battle slice against the canonical 393×852
reference in `docs/visual-parity/forged-ui/battle.png`, preserving the existing
Battle scene, HUD, tab, Settings, accessibility, routing, and gameplay-state
owners.

## Changes finalized

- Pinned the regular Battle chrome to the reference bands: resource/Settings at
  top-origin y=56, city progress at y=112, recommendation at y=168,
  battlefield at y=216, medallions at y=642, Deploy at y=704, and the 82pt tab
  shell at y=770.
- Kept the compact layout adaptive while retaining the existing battlefield
  visibility floors and 44pt hit-target checks.
- Split city progress and uppercase city identity, removed the redundant HP
  number label, and retained the 14pt segmented HP bar.
- Kept recommendation level detail derived from the existing city building
  state and moved cost/multiplier/lock data into the existing HUD visuals.
- Finalized transparent tinted SF-symbol rendering, procedural coin rendering,
  continuous forged panel gradients, hexagonal medallion plates, forged tabs,
  Settings gear treatment, and the Battle warm gradient/vignette atmosphere.
- Corrected the interrupted diff's recommendation placement and top-band
  boundary so the canonical layout does not self-reject for overlap.
- Added/updated focused layout, HUD, component, tab, Settings, and Battle tests
  for the source-level contracts.

## Static verification

Targeted SwiftLint command:

```text
swiftlint lint --quiet --no-cache --force-exclude \
  Pyxis/BattleChromeLayout.swift Pyxis/BattleHUDNode.swift Pyxis/BattleScene.swift \
  Pyxis/FeedbackSettingsController.swift Pyxis/GameUIComponents.swift \
  Pyxis/GameplayTabBarNode.swift Pyxis/SettingsGearNode.swift \
  PyxisTests/BattleChromeLayoutTests.swift PyxisTests/BattleHUDNodeTests.swift \
  PyxisTests/BattleSceneTests.swift PyxisTests/FeedbackSettingsNodeTests.swift \
  PyxisTests/GameUIComponentsTests.swift PyxisTests/GameplayTabBarNodeTests.swift
```

Result: exit 0. SwiftLint reports one existing line-length warning at
`Pyxis/BattleScene.swift:1762`; that line is outside the Task 11 edited hunk.

`git diff --check`: exit 0.

## Runtime gates not executed

Per the bounded finalization instruction, no `xcodebuild`, simulator/simctl,
Xcode, GUI, or screenshot-capture command was run. Therefore the focused Swift
tests, full test suite, deterministic 393×852 Battle fixture launch, native
pixel capture, side-by-side comparison, and 50% overlay inspection remain
unexecuted and require a host with a concrete simulator destination.

## Status

DONE_WITH_CONCERNS: the source/test slice is committed after static checks, but
runtime and visual parity evidence is still an open gate.

## Fix round 1/5: canonical safe-area top-band containment

Reviewer finding: with the canonical 393x852 input and top/bottom insets of
59/34, safeFrame.maxY is 793 while the authored income and Settings frames
end at y=796. The previous regular topBandFrame therefore failed its
containment guards and caused the Battle HUD to enter unsupported geometry.

The regular top band now uses the scene-authored extent
sceneFrame.maxY - battlefieldFrame.maxY. The direct arithmetic check printed:

safeFrame.maxY=793
fieldFrame=210...636 (height=426)
incomeFrame=750...796
topBandFrame=636...852
containsIncome=true

The covering assertion pins layout.topBandFrame.maxY == sceneHeight for the
canonical inset fixture. Gameplay hit-frame safe-area checks remain unchanged.

Exact arithmetic command: `rtk awk 'BEGIN { scene=852; safeTop=59; safeBottom=34; fieldMin=210; fieldMax=scene-216; safeMax=scene-safeTop; incomeMin=scene-102; incomeMax=incomeMin+46; topBandMin=fieldMax; topBandMax=scene; printf "safeFrame.maxY=%g\\nfieldFrame=%g...%g (height=%g)\\nincomeFrame=%g...%g\\ntopBandFrame=%g...%g\\ncontainsIncome=%s\\n", safeMax, fieldMin, fieldMax, fieldMax-fieldMin, incomeMin, incomeMax, topBandMin, topBandMax, (incomeMin >= topBandMin && incomeMax <= topBandMax ? "true" : "false") }'`.

Result: exit 0, with the output shown above.

Targeted SwiftLint command: `rtk swiftlint lint --quiet --no-cache --force-exclude Pyxis/BattleChromeLayout.swift PyxisTests/BattleChromeLayoutTests.swift`.

Result: exit 0, no warnings.

Diff check command: `rtk git diff --check`.

Result: exit 0.

No simulator, xcodebuild, simctl, Xcode, GUI, or screenshot-capture command
was executed. The focused Swift tests and fresh 393x852 native visual capture
remain explicitly unexecuted because no concrete simulator destination is
available. Status remains DONE_WITH_CONCERNS pending those runtime gates.

## Fix round 2/5: modal hit probe, canonical gear size, and multiplier precision

The parity run on `b519f5c` exposed three focused failures. The Settings modal
already owns the production touch path and returns before Battle HUD routing;
the failing test probe was instead landing inside the modal's full-width Done
button. Its first tab-edge tap closed Settings, so the following tab tap could
reach the underlying Battle router. The test now probes the exposed edge above
the modal close frame while remaining inside each tab hit frame, preserving the
valid Done action and accessibility behavior. The tall 393x852 fixture now
expects the canonical 46x46 gear frame while the compact fixture retains its
44x44 frame. The shared HUD multiplier formatter now uses fixed two-decimal
formatting, so favorable and disadvantaged values render as `1.25` and `0.80`.

Focused parity command (serial):

```text
XcodeBuildMCP test_sim --extraArgs "-parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleSceneTests/battleSettingsBlocksInputAndPausesTheBattlefieldActionLayer \
  -only-testing:PyxisTests/BattleSceneTests/battleHUDReservesSettingsSpaceAcrossPhoneFixtures \
  -only-testing:PyxisTests/BattleHUDNodeTests/referenceHierarchySeparatesCityIdentityAndKeepsMedallionsPortraitLed"
```

Result: 3 tests passed, 0 failed, 0 skipped (83.6s). XcodeBuildMCP emitted
two pre-existing Swift concurrency warnings in
`PyxisTests/GameplayFeedbackTestDoubles.swift:19` and an unknown source
location; neither was a test failure.

Affected-suite parity command (serial):

```text
XcodeBuildMCP test_sim --extraArgs "-parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleChromeLayoutTests \
  -only-testing:PyxisTests/BattleHUDNodeTests \
  -only-testing:PyxisTests/BattleSceneTests \
  -only-testing:PyxisTests/FeedbackSettingsNodeTests \
  -only-testing:PyxisTests/GameUIComponentsTests \
  -only-testing:PyxisTests/GameplayTabBarNodeTests"
```

Result: 223 tests passed, 0 failed, 0 skipped (73.6s), on simulator
`771133AB-2A09-4C6E-85FD-9D7523E8D2C7` (`Pyxis-Parity-393x852`).

Targeted SwiftLint command:

```text
rtk swiftlint lint --quiet --no-cache --force-exclude \
  Pyxis/BattleHUDNode.swift PyxisTests/BattleSceneTests.swift
```

Result: exit 0, no warnings.

Diff check command: `rtk git diff --check`.

Result: exit 0.

Per the round-2 instruction, no screenshot, GUI, or pixel-capture command was
executed. Visual capture remains an explicit unexecuted gate for a later round;
the simulator test gate is green. Status: DONE.

### Final round-2 verification after the disadvantaged-value assertion

The focused command above was rerun unchanged after adding the explicit `0.80`
assertion. Result: 3 tests passed, 0 failed, 0 skipped (45.8s). XcodeBuildMCP
reported one pre-existing main-actor warning at
`PyxisTests/GameplayFeedbackTestDoubles.swift:19`.

The six-suite command above was also rerun against the final tree. Result: 223
tests passed, 0 failed, 0 skipped (55.7s) on simulator
`771133AB-2A09-4C6E-85FD-9D7523E8D2C7` (`Pyxis-Parity-393x852`).

Final targeted SwiftLint command:
`rtk swiftlint lint --quiet --no-cache --force-exclude Pyxis/BattleHUDNode.swift PyxisTests/BattleHUDNodeTests.swift PyxisTests/BattleSceneTests.swift`.
Result: exit 0, no warnings. Final `rtk git diff --check`: exit 0. No
screenshot/capture command was executed.

## Fix round 3/5: icon, marker, and cluster alignment correction

The visual comparison found six remaining source-level mismatches. The city
progress and 21pt uppercase title now form one centered label group over the
centered 288x14 HP bar. Deploy now lays out the 46pt portrait, 18pt DEPLOY
label, 1x22 divider, and 13pt count as one centered cluster; the count frame
was moved into that cluster rather than reserving the far-right edge. Camp and
Map tabs now use 25pt outline `SKShapeNode` glyphs alongside the existing
crossed-swords outline. Settings uses a 21pt two-circle/eight-spoke outline
gear while retaining its existing tile, owner, and hit frame. OPEN/HELD chips
now include small shield paths, locked medallion pills use a small outline lock
path beside their city number, and forged selected panels use a warmer amber
surface plus visible glow through the existing `PanelNode` selected style.

Focused red/green command (serial):

```text
XcodeBuildMCP test_sim --extraArgs "-parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleHUDNodeTests \
  -only-testing:PyxisTests/GameplayTabBarNodeTests \
  -only-testing:PyxisTests/GameUIComponentsTests \
  -only-testing:PyxisTests/FeedbackSettingsNodeTests"
```

The pre-implementation run failed in the intended focused assertions for
left-biased city labels, the absent deploy divider, missing shield/lock vector
nodes, raster Camp/Map icons, and dark forged selected styling. After the
minimal owner-local implementation, the same command passed 32/32 tests.

Affected-suite parity command (serial):

```text
XcodeBuildMCP test_sim --extraArgs "-parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleChromeLayoutTests \
  -only-testing:PyxisTests/BattleHUDNodeTests \
  -only-testing:PyxisTests/BattleSceneTests \
  -only-testing:PyxisTests/FeedbackSettingsNodeTests \
  -only-testing:PyxisTests/GameUIComponentsTests \
  -only-testing:PyxisTests/GameplayTabBarNodeTests"
```

Result: 227 tests passed, 0 failed, 0 skipped (36.3s) on simulator
`771133AB-2A09-4C6E-85FD-9D7523E8D2C7`. XcodeBuildMCP reported one
pre-existing main-actor warning at
`PyxisTests/GameplayFeedbackTestDoubles.swift:19`; it did not affect the
result.

Targeted SwiftLint command:
`rtk swiftlint lint --quiet --no-cache --force-exclude Pyxis/BattleChromeLayout.swift Pyxis/BattleHUDNode.swift Pyxis/GameplayTabBarNode.swift Pyxis/GameUIComponents.swift Pyxis/SettingsGearNode.swift PyxisTests/BattleChromeLayoutTests.swift PyxisTests/BattleHUDNodeTests.swift PyxisTests/GameplayTabBarNodeTests.swift PyxisTests/GameUIComponentsTests.swift PyxisTests/FeedbackSettingsNodeTests.swift`.
Result: exit 0, no warnings. `rtk git diff --check`: exit 0.

No screenshot or pixel-capture command was executed, per the round-3
instruction; the controller-owned visual comparison remains the final visual
gate.

## Fix round 4/5: forged texture tint and dead-code cleanup

The remaining material mismatch was isolated to `PanelNode.applyStyle`: forged
plates installed a gradient texture but retained the dark bottom color as the
SpriteKit texture tint, multiplying the authored gradient toward black. Forged
plates now use a white fill tint while the gradient texture continues to carry
the authored warm top/bottom colors; standard plates still use their existing
fill color with no texture. The selected and primary-action material readbacks
continue to assert their requested gradient texture, stroke alpha, and glow
width/alpha. Battle HUD and Settings gear readbacks now assert the white forged
tint plus their unchanged authored strokes.

The orphaned `gameUISymbolImage` renderer and the obsolete vector-era
`iconColorBlendFactorForTesting` / `glyphColorBlendFactorForTesting` hooks were
removed now that all relevant glyphs are `SKShapeNode`s.

TDD red run (serial):

```text
XcodeBuildMCP test_sim --extraArgs "-parallel-testing-enabled NO
  -only-testing:PyxisTests/GameUIComponentsTests"
```

Before the production tint fix, the suite reported 8 passed, 1 failed; the
new white-tint assertions failed with the forged plate tint readbacks at
`0.20` / `0.439` red and `0.12` / `0.282` green, confirming the reported
darkening path.

Focused component/tab/gear verification (serial, simulator
`771133AB-2A09-4C6E-85FD-9D7523E8D2C7`):

```text
XcodeBuildMCP test_sim --extraArgs "-parallel-testing-enabled NO
  -only-testing:PyxisTests/GameUIComponentsTests
  -only-testing:PyxisTests/GameplayTabBarNodeTests
  -only-testing:PyxisTests/FeedbackSettingsNodeTests"
```

Result: 20 tests passed, 0 failed, 0 skipped. XcodeBuildMCP reported one
pre-existing main-actor warning at
`PyxisTests/GameplayFeedbackTestDoubles.swift:19`.

Affected-suite verification (serial, same simulator):

```text
XcodeBuildMCP test_sim --extraArgs "-parallel-testing-enabled NO
  -only-testing:PyxisTests/BattleChromeLayoutTests
  -only-testing:PyxisTests/BattleHUDNodeTests
  -only-testing:PyxisTests/BattleSceneTests
  -only-testing:PyxisTests/FeedbackSettingsNodeTests
  -only-testing:PyxisTests/GameUIComponentsTests
  -only-testing:PyxisTests/GameplayTabBarNodeTests"
```

Result: 227 tests passed, 0 failed, 0 skipped. Targeted SwiftLint over the
seven changed source/test files exited 0 with no warnings, and `git diff
--check` exited 0. No screenshot or pixel-capture command was executed.

Status: DONE pending controller-owned decisive visual capture.

## Fix round 5/5: Battle-normal runtime evidence package

No source or test code changed in this round. The exact current runtime capture
was supplied by the `Pyxis-Parity-393x852` simulator at commit `4700f3e`:

```text
/var/folders/_k/lkrpcd8516s5x5szmkq1mbvc0000gn/T/screenshot_optimized_0944417b-f967-4425-ad1c-98c398ebcdba.jpg
```

The XcodeBuildMCP screenshot transport is an optimized 369×800 JPEG for the
exact logical 393×852 fixture. The archived `@3x` board artifact is therefore
resampled content, not recovered framebuffer detail.

Exact artifact commands:

```text
ffmpeg -hide_banner -loglevel error -y -i /var/folders/_k/lkrpcd8516s5x5szmkq1mbvc0000gn/T/screenshot_optimized_0944417b-f967-4425-ad1c-98c398ebcdba.jpg -vf "scale=1179:2556:flags=lanczos,format=rgba" -frames:v 1 docs/visual-parity/forged-ui/native/battle-normal-393x852@3x.png

ffmpeg -hide_banner -loglevel error -y -i docs/visual-parity/forged-ui/battle.png -i docs/visual-parity/forged-ui/native/battle-normal-393x852@3x.png -filter_complex "[0:v]scale=1179:2556:flags=lanczos,format=rgba[canonical];[1:v]format=rgba[runtime];[canonical][runtime]blend=all_mode=average,format=rgb24[overlay]" -map "[overlay]" -frames:v 1 docs/visual-parity/forged-ui/overlays/battle-normal-50-overlay.png

ffmpeg -hide_banner -loglevel error -y -i docs/visual-parity/forged-ui/battle.png -i /var/folders/_k/lkrpcd8516s5x5szmkq1mbvc0000gn/T/screenshot_optimized_0944417b-f967-4425-ad1c-98c398ebcdba.jpg -filter_complex "[0:v]scale=369:800:flags=lanczos,format=rgb24[canonical];[1:v]scale=369:800:flags=lanczos,format=rgb24[runtime];[canonical][runtime]hstack=inputs=2,format=rgb24[side]" -map "[side]" -frames:v 1 docs/visual-parity/forged-ui/battle-style-side-by-side.png
```

Inspection with `file` and `sips -g pixelWidth -g pixelHeight` confirmed the
native and overlay artifacts are 1179×2556 PNGs and the side-by-side is a
738×800 PNG containing canonical-left/runtime-right 369×800 halves. Visual
inspection confirmed the deliberate state/content difference: runtime is
4.2K / 20 / 0 soldiers versus prototype 7.4K / 320 / 6 with active units and
damage; layout/style bands are the comparison target. `git diff --check`
exited 0.

Provenance: the ffmpeg commands listed above DID run during this round and
produced the task-11 artifacts — the 1179×2556 native framebuffer (committed
unchanged), plus the then-current 1179×2556 overlay and 738×800 side-by-side.
No source edits, test edits, or test runs were performed in this round. The
committed overlay (now 393×852) and side-by-side (now 786×852) were refreshed
by later capture rounds documented in `docs/visual-parity/forged-ui/README.md`
and supersede the task-11 outputs; the native file's 1179×2556 dimensions
remain the committed verification evidence.

Evidence paths:

```text
docs/visual-parity/forged-ui/native/battle-normal-393x852@3x.png
docs/visual-parity/forged-ui/overlays/battle-normal-50-overlay.png
docs/visual-parity/forged-ui/battle-style-side-by-side.png
docs/visual-parity/forged-ui/README.md
```
