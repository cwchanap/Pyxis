# Consolidated final-fix report

Base: `6dece6b2bc09c731724f773648a6290a7b9ba47d`

Scope: final whole-branch review findings only. The patch keeps the existing Battle, Map, report, persistence, routing, and presentation owners; it adds no new platform, generic cache, or persistence abstraction.

## Findings addressed

### Battle tab safe-area interaction

`BattleChromeLayout.tabHitFrames` is the authoritative safe-area projection. `BattleHUDNode` now passes those frames into `GameplayTabBarNode` for Battle presentation, while Camp and Map retain their existing local tab-bar behavior. The tab bar continues to own visual layout and only replaces enabled Battle interaction frames with the supplied layout frames.

`BattleSceneTests.touchesEndedBattleTabUsesAuthoritativeSafeHitFrame` mounts a Battle scene in a 393×852 view with a 34 pt bottom safe-area inset, taps the lower edge of the actual Map tab frame, and verifies the route. The test also asserts the frame remains inside `layout.safeFrame`.

### Scout trait multipliers

`CountryMapScoutCardNode` now carries the existing `CityDefenseTrait.damageMultiplier(for:)` projection through prepared and rendered footer items, readback, and debug visible text. The footer renders the approved `×1.25` or `×0.80` beside the favorable/disadvantaged type group; standard and empty groups remain without a multiplier.

`CountryMapScoutCardNodeTests.footerReadbackAndVisibleTextIncludeTraitMultipliers` verifies both rendered/readback multipliers and the combined visible footer text. Existing acceptance fixtures were updated to assert the same approved copy.

### Idle report persistence and truthful projection

The presentation-only `BattleResult.idleBuildingCount` property, coding key, initializer argument, encoder/decoder handling, and production capture were removed. Unknown legacy JSON keys remain safely ignored by decoding and are omitted on re-encoding; no replacement persistence field or key was added.

Idle report content now projects `BattleResult.totalIdleDamage` from existing durable `idleDamageByType` evidence. A result with durable rows shows `IDLE DAMAGE` and the saturated total; a legacy/current result with no rows shows `IDLE DAMAGE` and `—`. This preserves truthful evidence after the conquered city's building grid is cleared and avoids rendering a false `BUILDINGS 0`.

`BattleResultModelsTests.idleReportProjectionUsesDurableDamageAndDropsLegacyBuildingCount` covers current JSON carrying the old unknown key, legacy JSON without it, and an empty idle result. Conquest content, game-state, scene, controller, fixture, and UI expectations now use the durable projection.

### Fixed Forged texture reuse

The existing owners now reuse fixed presentation textures on redraw:

- `BattleHUDNode` keeps one static procedural coin texture for both gold icons.
- `BattleScene` keeps the last generated Forged atmosphere texture keyed by its current size.
- `PanelNode` keeps a small style-keyed cache for its fixed Forged gradients.

No generic cache subsystem was introduced. `BattleHUDNodeTests.forgedGoldTexturesReuseOneSharedCoinAcrossRedraws`, `GameUIComponentsTests.forgedPanelReusesItsFixedGradientTextureAcrossReapply`, and the existing atmosphere redraw test provide observable identity coverage.

## TDD and verification evidence

The initial focused red run was executed before implementation:

```text
xcodebuild test ... -parallel-testing-enabled NO \
  -only-testing:PyxisTests/BattleSceneTests \
  -only-testing:PyxisTests/CountryMapScoutCardNodeTests \
  -only-testing:PyxisTests/BattleResultModelsTests \
  -only-testing:PyxisTests/GameUIComponentsTests
```

It ran 240 tests in four suites and produced the expected failures for the unsafe Battle hit frame, missing Scout multipliers, stale idle BUILDINGS projection, and texture identity behavior. After implementation and the necessary semantic fixture updates, the affected run passed 250/250; the expanded BattleScene/BattleHUD run passed 201/201, including the actual safe-area touch and shared-coin regressions.

Final serial verification used direct `xcodebuild` because XcodeBuildMCP was not available:

- `xcodebuild test -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=Pyxis-Parity-393x852' -parallel-testing-enabled NO -only-testing:PyxisTests` — 875 tests in 55 suites passed.
- The same serial destination with `-only-testing:PyxisUITests` — 5 UI tests passed, 0 failures.
- `swiftlint lint --quiet --no-cache --force-exclude` on the changed Swift files — exit 0; existing warnings only, with no serious violations.
- `git diff --check` — passed with no whitespace errors.

## Changed files

Production:

- `Pyxis/BattleHUDNode.swift`
- `Pyxis/BattleResultModels.swift`
- `Pyxis/BattleScene.swift`
- `Pyxis/ConquestReportContent.swift`
- `Pyxis/CountryMapScoutCardNode.swift`
- `Pyxis/GameUIComponents.swift`
- `Pyxis/GameViewController.swift`
- `Pyxis/GameplayTabBarNode.swift`
- `Pyxis/KingdomGameState.swift`

Tests:

- `PyxisTests/BattleHUDNodeTests.swift`
- `PyxisTests/BattleResultModelsTests.swift`
- `PyxisTests/BattleSceneTests.swift`
- `PyxisTests/ConquestReportContentTests.swift`
- `PyxisTests/CountryMapScoutCardAcceptanceTests.swift`
- `PyxisTests/CountryMapScoutCardNodeTests.swift`
- `PyxisTests/ForgedVisualFixtureTests.swift`
- `PyxisTests/GameUIComponentsTests.swift`
- `PyxisTests/GameViewControllerTests.swift`
- `PyxisTests/KingdomGameStateTests.swift`
- `PyxisUITests/PyxisUITests.swift`

SDD:

- `progress.md`
- `final-fix-report.md`

Deliberate compromise: exact idle building count is unavailable from the durable `BattleResult` after the building grid is cleared. The report therefore uses the existing durable total idle damage and an em dash for missing evidence. The old `idleBuildingCount` string appears only in decoding fixtures to prove legacy compatibility; it is not a model property, coding key, or emitted persistence field.
