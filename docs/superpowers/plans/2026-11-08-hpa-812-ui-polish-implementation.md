# HPA-812 — Cross-scene UI polish: single-PR implementation plan

**Linear:** https://linear.app/cwchanap/issue/HPA-812/polish-ui-rough-edges-across-camp-map-kingdom-and-battle  
**Design:** [HPA-812 UI polish design](../specs/2026-11-08-hpa-812-ui-polish-design.md)  
**Baseline:** cwchanap/Pyxis main@bb390f08fa68c5c4ce6e349fad3d67dbe791b144 (after the HPA-811 merge).  
**UAT reference:** main@98c9d35, iPhone 17 simulator, per Linear issue.  
**Delivery:** One HPA-812 PR, beginning as a draft with these two planning documents. Continue all implementation, tests, screenshots and review fixes **on this same PR**, and do not merge docs alone or open a second implementation PR. No production code has changed in this planning checkpoint.

## Architectural decisions

Keep SpriteKit scenes as presentation owners and the current pure geometry helpers as the only layout authorities: CampChromeLayout, CountryMapLayout, KingdomLayout, BattlefieldLayout and ConquestReportLayout. Reuse existing GameUITheme, PanelNode, GameplayTabBarNode, Settings controller, gold icon assets and forged treatment; do not introduce a new design system, event bus, animation-pool abstraction, scroll framework or new saved fields.

HPA-812 changes only rendering/interaction affordances. Preserve KingdomGameState/BattleCombatState calculations, gold, equipment cycles, the exact map authored anchors, idle catch-up, stage routing, the pending conquest report, Ascension's two-tap confirmation and existing 44pt accessibility hit targets. No new image art, music, SFX or haptics. Any genuinely needed new art/SFX is a *separate* task outside HPA-812.

## Checkpoint 0 — Verify against current main, before any code changes

1. Build/run on an available macOS Xcode iPhone simulator, preferring iPhone 17. Confirm the repository baseline and capture current screenshots, not only the Nov 7 UAT report. The original main@98c9d35 predates the merged HPA-811.
2. Reproduce and record every numbered observation **#1–#17**. Use launch fixtures where available (particularly fresh Map, 15/15 country completion, Ascend armed, busy Battle). Note items already resolved on main and do not churn code to re-fix them.
3. Preserve screenshot evidence for: Camp none/empty/occupied selection at one fixed viewport; Map fresh/complete; locked tabs; Kingdom Treasury/Armory/Ascend; frequent gate hits and busy lanes; conquest report.
4. Run relevant existing focused tests before modifying the affected layouts to identify baseline assumptions. In particular, inspect the current compact-phone and iPad portrait geometry fixtures.
5. The DEBUG five-tap city jump was marked **not tested** rather than a confirmed HPA-812 problem. Optionally check with actual supported taps, but never add a repair to this UI PR without a reproduced defect and separate scope decision.

**Gate:** A per-numbered-item before-state table differentiates confirmed reproducible, already fixed, and unable-to-reproduce. No screenshot or simulator validation is claimed by this design-only PR yet.

## Checkpoint 1 — Camp stability and affordances (#1–#5)

**Files:** Pyxis/CampChromeLayout.swift, Pyxis/CampSelectionNode.swift, Pyxis/BuildingViewScene.swift; tests in PyxisTests/CampChromeLayoutTests.swift, CampSelectionNodeTests.swift, BuildingViewSceneTests.swift.

1. **Red tests for #1:** For the same scene size/insets and each lot, compute layouts for .none, .emptyLot and .occupiedLot; assert all 25 visual centers and their 44pt hit frames are invariant across selection. Check 393×852 with 59/34 safe-area insets, 375×667, 320×568, and the existing supported iPad portrait fixture. Preserve no-overlap with tab bar and selection panel.
2. **Layout fix:** Reserve a single bottom selection allocation sized for the compact palette/inspector regardless of selection; the selection node can remain hidden when nothing is selected. Keep scenic region and anchor calculations stable; verify this does not cause the 320×568 fixture to fail. If the current 174pt panel is too tall, shrink only the palette's empty whitespace and fit text/actions into the smaller stable allocation. Do not move the lot grid in BuildingViewScene manually.
3. **#2:** Remove CampChromeLayout's staggered palette yOffsets and align all five option card frames; reduce unused top padding. In CampSelectionNode inset status/cost labels so measured content no longer clips the bottom border, preserving recommended marker and min 44pt hit target. Assert panel containment and visible text bounding boxes, including multi-digit costs/locked labels.
4. **#3:** In CampSelectionNode's inspector style selection, prioritize not-upgradable/insufficient-gold over isRecommended: disabled first, then recommended, then normal actionable. Use the existing CampSelectionContent.canUpgrade projection. Existing tap feedback may still explain insufficient gold; assert gold/building levels do not change when unaffordable.
5. **#4–#5:** Give the existing status feedback a small high-contrast dark/forged backing or readable shadow over grass, with no persistent notification. Add the existing Battle/Map gold icon to the Camp gold HUD and fit number/icon inside the 48pt panel; use the current gold formatting and theme.
6. Run Camp-focused geometry, node and scene tests, and visually check tap-to-open/tap-to-build/upgrade transitions on the reference phone.

**Gate:** Opening/closing either panel never moves any lot center; all five cards align and costs are visible; an unaffordable recommended upgrade is clearly disabled; status and gold are legible.

## Checkpoint 2 — Map legibility, layout and completion guidance (#6–#9)

**Files:** Pyxis/CountryMapLayout.swift, CountryMapScene.swift, CountryMapScoutCardNode.swift, optionally existing scout card layout/text owners; tests in CountryMapLayoutTests, CountryMapSceneTests, CountryMapScoutCardNodeTests, CountryMapScoutCardLayoutTests, CountryMapScoutCardAcceptanceTests.

1. **#6:** Reproduce first-run city1/city2 visibility and hit testing. Assert the card/overlay and 44pt city hit frames are disjoint with a small visible margin and that the map interaction envelope fits on the currently supported portrait sizes. If not, adjust the CountryMapLayout information-card/map-region vertical budget and existing envelope computation, not individual city anchors or ad-hoc SpriteKit offsets. The source artwork, authored routes, fail-closed layout gate, and region containment checks must remain authoritative. Verify current-city marker visible, both cities tappable, card action still tappable.
2. **#7:** For countryComplete only, change the card from one centered line into a compact title plus “Next: Kingdom → Ascend to begin again.” Use only current layout's bounded content region, fit both lines with existing font fitter and guard compact viewports. Do not create an Ascend shortcut/button or restore an Attack hit target when complete; Kingdom tab remains the navigation route. Test text and state.
3. **#8:** Replace hard-coded 32pt progress-label reservation with an explicitly measured/fitted label width and a nonzero gap. Derive pip region from the leftover width, maintain 15 visible pips where layout supports it, and assert nonintersection with 0/15, 9/15 and 15/15 labels at compact/reference widths. Fail gracefully on truly unsupported space instead of drawing overlap.
4. **#9:** Address flat dark color bands by matching existing forged/background tone or applying a subtle scene-owned theme transition; do not stretch/map authored art, edit the image, add texture assets or change map hit testing.
5. Run layout, scout-card and Map scene tests and compare before/after screenshots of fresh and fully completed runs.

**Gate:** Initial map cities are unobstructed; final card points toward Kingdom → Ascend; pips and labels remain separate; visual band treatment does not alter world positions.

## Checkpoint 3 — Shared tabs and Kingdom (#10–#14)

**Files:** Pyxis/GameplayTabBarNode.swift, KingdomLayout.swift, KingdomScene.swift; tests in GameplayTabBarNodeTests, KingdomLayoutTests, KingdomSceneTests, GameViewControllerTests.

1. **#10 locked tabs:** Current forged GameplayTabBarNode sets near-identical alpha for enabled-unselected and disabled icons; assign clearly different muted colors/opacity and disabled panel treatment when the tab is not in content.enabledTabs. Keep locked tabs absent from hitFrames, keep selected tab highlighted, and preserve pending-report routing. Test both appearance variants and states (battle active, pending, conquered).
2. **#11 Kingdom header:** Measure visible forged bezel/pill overflow, not only CGRect hit-target containment. Reposition/shrink/inset the selector and gear visual treatments within headerFrame and shift goldLabel farther from the left decoration while preserving a readable gold/renown width and 44pt gear/selector interaction frames. Do not add a second Settings node.
3. **#12 rows:** For tall phones, distribute/center the existing three Treasury and five Armory rows in their content bands; retain existing minimum row height, row text frames and 44pt action targets on compact phones. Do not add filler rows, scrolling or a new layout engine. Keep selection and redraw state unchanged.
4. **#13 Armory action:** Add a small chevron or concise “tap to change” affordance for soldier rows that own gear (using the existing row geometry, without overflowing packed line2). Keep unowned rows inert and visibly differentiated. Add/retain a VoiceOver hint that describes cycling through owned items, including None, without duplicating the equipment selection logic.
5. **#14 Ascend:** Inset primaryPanel's *visible* fill/glow enough to remain within the parent Ascend border at all supported sizes, but preserve the existing 44pt hit frame and separate Cancel; keep the two-tap confirmation and its complete-run gating unchanged. Add geometrical containment and scene readback assertions.
6. Run shared-tab, Kingdom geometry, Kingdom scene and controller route tests. Smoke Treasury purchase, gear cycling, arm/cancel/confirm Ascension, and locked/unlocked tab transitions.

**Gate:** Tabs visibly convey disabled state; Kingdom header and Ascend glow remain visually contained; Armory visibly communicates its full-row cycle; all original gameplay interactions still work.

## Checkpoint 4 — Battle-only visual clarity (#15–#17)

**Files:** Pyxis/BattleScene.swift, ConquestReportNode.swift; optionally existing BattlefieldLayout.swift if genuinely necessary. Tests in BattleSceneTests, BattleSceneCoverageTests, ConquestReportNodeTests and BattlefieldLayoutTests.

1. **#15 numbers:** Record the visual behavior with repeated same-gate hit events. Add a small, *scene-local* bounded floating-label presentation rule: stagger or coalesce labels sharing a close impact position, and retire/suppress purely cosmetic excess within the short existing lifetime. Keep damage calculations, recorded event count, sound/haptic dispatch and conquest unaffected. Preserve Reduce Motion's non-moving fade. Test number of visible labels and nonidentical positions in a deterministic fixture, rather than introducing a general animation manager.
2. **#16 soldiers/HP:** In the current scene-only SoldierFormation offsets (three columns, 0.42 lateral / 0.30 row height) and syncSoldierNodes, tune spacing/overflow placement to avoid soldiers all stacking at the clamped floor in normal crowded lanes. Test that bodies and hp bars remain within visible battlefield and clear of enemy gate sprites while the objective is active. The model's lane/position, spawn behavior, HP, targeting, and damage are unchanged; do not introduce gameplay collision or a global soldier cap. Keep geometry change minimal and use existing battlefield frame constraints.
3. **#17 medallion:** Scale ConquestReportNode's currently fixed 32×32 conquered-marker icon by the existing 96/118pt takenMedallionFrame, retaining the “TAKEN” label and ring spacing. Verify both compact and reference medallion tests.
4. Visually inspect dense infantry near gate, repeated -2 feedback, Reduce Motion and conquest completion before/after.

**Gate:** Frequent hit feedback is legible; scene bodies/HP are not visually swallowed by the gate; the crest feels proportionate. Battle mechanics, save and result data are unchanged.

## Checkpoint 5 — Final evidence, CI and PR readiness

1. Run focused model/layout/scene tests after each checkpoint (TDD for changed behavior). Re-run all existing Swift Testing unit tests and XCTest UI tests serially, with parallel simulation disabled, plus SwiftLint:
   
       xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -destination 'platform=iOS Simulator,name=iPhone 17' -parallel-testing-enabled NO test
       swiftlint lint

   If iPhone 17 is unavailable, use xcodebuild -showdestinations and record the actual simulator. Confirm GitHub Build & Lint, Unit/Codecov, and UI Test workflows.
2. Screenshot/interactive checks at compact 320×568 and 375×667, reference 393×852 with safe insets and iPad portrait 834×1194, plus resize/gate recovery where supported. Keep fixtures and artwork registration intact.
3. Verify no Regression in: Camp palette+upgrade authorization, Map Attack/Scout tap priority, finished-run Map/Kingdom routing, locked tab behavior, Armory equipment cycling/accessible hint, Ascension confirmation, pending conquest report, idle/background progression and scene recreation. The current 15-city opt-in balance campaign is **not required** for styling-only changes, unless implementation unexpectedly alters a balance constant (which is out of scope).
4. Post a concise evidence table in this PR covering **all 17 issue numbers** with code change or current-main already-fixed disposition, linked focused tests, before/after screenshots and residual concerns. No silent “fixed” status when it cannot be reproduced or verified.
5. Update CLAUDE.md only if an enduring architecture/convention changed (not expected). Re-review the final diff, address valid review comments **on this branch**, and mark ready only after implementation and evidence are present.

## Guardrails and stop conditions

- **One ticket → one PR:** Do not merge planning documents alone; continue implementation, tests and review revisions here.
- Do not change saved format, gameplay/economy formulas, combat/event semantics, map source-city coordinates, launch/router contracts or accessibility hit minima.
- If a fix makes the accepted 320×568/portrait iPad layouts unsupported or causes a hard geometry conflict, record the failing fixture and revise this same design/plan rather than bypassing guards.
- Distinguish an originally reported visual problem from an actual reproduced issue on today's main. Keep no-op/unchanged cases explicitly noted and avoid speculative fixes.
- No art or SFX generation in this coding ticket. If new assets become truly necessary, create a separate asset task using an available Graveyard placeholder and leave the visual issue pending that dependency.

**Current checkpoint:** planning files only; no simulator, build, tests or visual UAT have run in this creation pass. The five checkpoints describe later implementation work on this same PR.
