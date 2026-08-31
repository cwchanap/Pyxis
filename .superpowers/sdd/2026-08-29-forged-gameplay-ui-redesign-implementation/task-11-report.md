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
