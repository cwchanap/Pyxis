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
