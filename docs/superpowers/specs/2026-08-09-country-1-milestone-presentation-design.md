# HPA-390 — Country 1 Milestone Presentation Design

## Status

Approved design for HPA-390: **Add presentation-only milestone treatment for Cities 5, 10, and 15**.

HPA-390 is the final player-visible HPA-360 roadmap slice before the HPA-567 Country 1 validation checkpoint. HPA-366 (Country 1 city identity) and HPA-365 (Recommended Camp guidance) are complete.

This design intentionally keeps milestone behavior presentation-only. It does not change combat, rewards, progression, persistence, buildings, lane rules, unit rules, or idle progress.

## Goals

Make Cities 5, 10, and 15 feel like increasingly important Country 1 moments while preserving Pyxis's simple casual loop.

Each milestone gets:

1. A short arrival banner using the existing authored city identity.
2. A modest decorative accent around the existing enemy-city presentation.
3. A fresh-conquest flourish around the existing conquest report.

City 15 additionally makes `Country 1 Complete` explicit before Continue returns to the completed country map.

The implementation must stay small enough that removing or revising the presentation after HPA-567 playtesting is cheap.

## Non-goals

HPA-390 does not add:

- boss mechanics or combat-rule changes;
- new rewards, unlocks, currencies, objectives, or achievements;
- persistence or save migration for consumed milestone presentation;
- unique backgrounds, cutscenes, dialogue, music, or new art assets;
- a milestone engine, presentation service, protocol hierarchy, registry, or reusable animation framework;
- milestone presentation for ordinary Country 1 cities;
- a generalized reduced-motion preference system;
- new gameplay SFX or haptic events.

## Existing code to reuse

The current repository already owns every lifecycle boundary HPA-390 needs:

- `Country1CityCatalog` / `CityDefinition` own the 15 authored names, one-line flavor text, and conquest titles.
- `BattleScene` owns the enemy-city node, combat HUD, input routing, effects layer, scene resize handling, and Settings/modal precedence.
- `BattleScene.presentPendingConquestReport(origin:resetsContinueState:)` already distinguishes `.freshLive`, `.freshIdle`, and `.restored` conquest presentation.
- `BattleScene.applyPendingConquestReport(resetsContinueState:)` already owns the single conquest-report fit-failure path: set `isConquestReportFitFailed`, hide the report, and ask the router for `.unsupportedGeometry`.
- Fresh reports already receive a one-shot gold burst, while restored reports intentionally do not replay that effect.
- `ConquestReportLayout` already computes the safe report panel and Continue geometry.
- `ConquestReportNode` already owns the report content and Continue hit target.
- `BattleSceneTests` already exercise both compact landscape and narrow portrait geometry, including `320×568`.

HPA-390 extends those scene-local presentation seams instead of creating a second presentation subsystem.

## Approaches considered

### A. BattleScene-local presentation with one tiny pure selector — selected

Add one small framework-free milestone selector and keep all actual SpriteKit nodes/lifecycle state inside `BattleScene`.

Advantages:

- follows current scene ownership;
- gives focused pure selection coverage without exposing BattleScene internals;
- reuses the existing city identity and conquest lifecycle;
- requires no persistence or new architectural layer;
- keeps the feature easy to delete or revise after HPA-567 playtesting.

### B. Add milestone presentation fields to `CityDefinition`

Rejected. `CityDefinition` currently owns shared authored city identity and gameplay metadata. Adding presentation tiers, colors, animation cues, or consumed state would make a shared content model carry one-scene presentation policy and invite speculative theme fields.

### C. Build a reusable milestone presentation node/engine

Rejected. There are only three fixed Country 1 consumers, and HPA-390 explicitly says not to create a general milestone presentation engine. A reusable abstraction would cost more code and maintenance than the feature warrants.

## Milestone selection

Add a small pure value such as `Country1MilestonePresentation` beside BattleScene.

It maps exactly:

- City 5 -> milestone tier 1;
- City 10 -> milestone tier 2;
- City 15 -> milestone tier 3 / country finale;
- every other city -> no milestone presentation.

The value contains only selection/tier information needed by the shipping BattleScene consumer. It must not duplicate `CityDefinition.name`, `flavorText`, or `conquestTitle`.

The tier exists only to choose three fixed visual strengths. Do not add generic style dictionaries, theme objects, arbitrary effect parameters, or future-country extension points.

## Authored text ownership

All player-facing milestone city text remains derived from the existing catalog:

- arrival title: `CityDefinition.displayTitle`;
- arrival subtitle: `CityDefinition.flavorText`;
- conquest title: the current conquest-report title resolved from `CityDefinition.conquestTitle`;
- final additional label: literal `Country 1 Complete` for City 15 only.

No parallel city-name or conquest-message switch is allowed.

HPA-390 intentionally supersedes only one HPA-366 presentation rule: overall country completion is no longer shown exclusively after Continue on the Country Map. The City 15 conquest title remains `Crownspire Keep Falls`, and the existing acknowledgement -> save -> Country Map transaction remains unchanged.

## Arrival banner

### Presentation

When an active BattleScene first mounts for City 5, 10, or 15, show one compact scene-owned banner containing:

- the full authored `City N · Name` title;
- the existing one-line flavor text.

The banner is presentation-only and does not pause combat simulation. It should remain visually readable without becoming another modal flow.

Use the current theme fonts/colors and a simple panel/shape treatment. Do not add an image asset or reusable banner component.

### Lifetime

- Present at most once for the mounted BattleScene instance.
- Auto-dismiss after approximately 1.5 seconds.
- A player tap while the banner is visible dismisses it immediately.
- That dismissal tap is fully consumed; Spawn, unit selection, World, Build, Settings, HUD info, and other underlying controls must not receive it.
- Resize/redraw/layout refresh may reposition the current banner but must not restart its presentation or reset its auto-dismiss timer.
- If a new BattleScene is reconstructed later, replay is acceptable before public release.
- Do not persist a consumed token.
- Any conquest-report presentation dismisses a still-visible arrival banner before applying the report so the two presentation surfaces never compete.

### Input precedence

Battle input precedence becomes:

1. conquest report / fit-failure gate;
2. visible milestone-arrival banner;
3. Settings modal;
4. Settings gear;
5. normal battle controls.

A pending/restored conquest report therefore never competes with an arrival banner.

## Enemy-city accent

Milestone battles receive one decorative accent around the existing enemy-city presentation.

The accent is a scene-owned `SKShapeNode` (or similarly minimal existing SpriteKit primitive) positioned from the enemy city's rendered geometry. It must not resize, reposition, replace, or add hit geometry to `enemyCityNode`.

Escalation is deliberately modest:

- City 5: thin accent;
- City 10: stronger stroke/glow treatment;
- City 15: strongest frame/glow treatment.

The same basic shape is reused at all three tiers. Escalation comes from a few fixed stroke/glow/inset constants, not separate implementations.

**HPA-390 keeps this enemy-city accent static.** A looping/pulsing city accent is explicitly deferred. The only motion in this ticket is the short arrival transition and the fresh conquest flourish. This avoids creating another long-lived animation lifecycle solely for decoration.

Layout refresh updates the accent geometry without replaying the arrival presentation.

Ordinary cities create no accent.

## Conquest flourish

### Fresh versus restored behavior

Hook the flourish into the existing `presentPendingConquestReport(origin:resetsContinueState:)` boundary.

After the existing report successfully applies:

- `.freshLive` milestone conquest -> show flourish once;
- `.freshIdle` milestone conquest -> show flourish once;
- `.restored` report -> do not replay the flourish.

This deliberately mirrors the current gold-burst fresh/restored behavior.

`applyPendingConquestReport` is also used during layout refresh. It may recompute/reapply geometry, but it must not increment the flourish presentation count or restart one-shot animation.

### Visual treatment

Use one scene-owned report accent positioned from the already-computed `ConquestReportLayout.panelFrame`, slightly outside the report panel so it remains visible without covering report text or Continue.

Escalate the same accent by milestone tier. Do not modify conquest reward calculations or create a second result modal.

The existing authored conquest title remains the primary result text; HPA-390 must not repeat that title in another label.

The report accent is decorative. If the accent itself cannot be drawn cleanly inside the safe frame, reduce/clamp/hide the accent rather than blocking Continue. Required text is what participates in fail-closed layout behavior.

### City 15 country-complete state

For City 15 fresh and restored reports, display a clear `Country 1 Complete` label associated with the report presentation.

The label is semantic state, not a one-shot animation, so it remains visible when a pending City 15 report is restored.

Keep it outside the report's existing summary rows rather than expanding `ConquestReportContent` to five rows or changing achievement semantics. Position it from the computed report/safe frames so it remains inside the safe area and does not overlap the report content or Continue.

`Country 1 Complete` is required HPA-390 text. If no valid frame exists for it, **the whole conquest presentation fails closed through BattleScene's existing report fit-failure authority**: mark `isConquestReportFitFailed`, hide the report/milestone treatment, request `.unsupportedGeometry`, and keep the pending result unacknowledged. Do not silently hide the completion label while treating the report as successfully presented.

Continue remains the existing `ConquestReportNode` control and follows the existing acknowledge -> save -> Country Map route. HPA-390 adds no alternate completion transaction.

## Motion and accessibility

Use `UIAccessibility.isReduceMotionEnabled` at presentation time.

Normal motion may use only short, non-looping emphasis such as fade/scale on arrival and fresh conquest. Reduced-motion behavior uses static framing and fades only.

All milestone meaning is carried by text:

- arrival city title + flavor;
- existing conquest title;
- `Country 1 Complete` for City 15.

Animation, glow, and color are reinforcement only.

Do not introduce a persisted motion setting, dependency protocol, manager, or accessibility subsystem for this ticket. Reduced-motion behavior is verified manually unless an existing test seam makes automated verification essentially free.

## Sound and haptics

Do not add new HPA-390 sound IDs, haptic events, catalog entries, assets, cooldowns, or feedback policy.

The existing conquest feedback remains unchanged. Presentation-only milestone visuals are sufficient for this slice; HPA-567 playtesting can provide evidence if additional reinforcement is actually needed.

## Scene-local state

BattleScene may add only the small state necessary to manage this presentation, for example:

- selected milestone presentation for the current city;
- whether the arrival banner has been presented/dismissed;
- scene-owned milestone nodes;
- whether a fresh conquest flourish has already run in this scene.

None of this state is persisted in `KingdomGameState`, `BattleResult`, `CityDefinition`, or `UserDefaults`.

## Layout behavior

Milestone decoration must respect the currently supported BattleScene layouts rather than introducing new layout infrastructure.

Automated fit gates cover all three representative constraints:

- `568×320` — very short landscape;
- `667×375` — compact landscape;
- `320×568` — narrow portrait and the hardest width for `City 15 · Crownspire Keep`.

Arrival banner:

- fits within the current safe/content width;
- both text lines remain contained and non-overlapping at all three fixtures;
- does not require moving existing HUD or battle controls.

Enemy-city accent:

- follows the actual rendered city frame;
- changes no battlefield geometry.

Conquest flourish / City 15 label:

- derives from the already-computed `ConquestReportLayout` safe/panel frames;
- report accent remains decorative and must not change Continue behavior;
- required `Country 1 Complete` remains within the safe area;
- required label does not intersect report content or Continue;
- never changes the existing Continue hit frame;
- no valid City 15 required-label frame means existing unsupported-geometry handling, not silent omission.

If required milestone text cannot meet supported-layout constraints, use the repository's existing layout-gate authority rather than silently clipping or dropping required text.

## Error handling

There is no new persistence or external I/O.

- Ordinary or out-of-scope cities simply have no milestone selection.
- Catalog text continues to use the existing HPA-366 lookup/fallback behavior.
- If the conquest report itself cannot fit, the existing BattleScene unsupported-geometry path remains authoritative.
- If City 15's required `Country 1 Complete` frame cannot fit, use that same unsupported-geometry path.
- Decorative accent failure must never mutate gameplay or block Continue by itself; required text fit is the fail-closed condition.

## Risks and fallback policy

### Risk 1 — outside-panel City 15 fit

The City 15 completion label is the only new required report content positioned outside `ConquestReportLayout.panelFrame`. This is the highest-risk geometry in HPA-390 because it must remain inside `safeFrame` without touching the report or Continue across short landscape and narrow portrait layouts.

Go/no-go verification is the dedicated City 15 fit test at `568×320`, `667×375`, and `320×568`. Task 3 is not green until all three pass.

If the label cannot fit, **fail closed using the existing report layout gate**. Do not solve the failure by adding a new layout engine, expanding `ConquestReportLayout`, persisting presentation state, or introducing another modal.

### Risk 2 — arrival text width

`City 15 · Crownspire Keep` is the longest milestone arrival title and `320×568` is the tightest width. Automated arrival frame/title/subtitle containment at all three fixtures is the gate. Use existing label fitting; do not create a new text-layout abstraction.

### Risk 3 — one-shot replay

`applyPendingConquestReport` runs for layout reapplication and Continue disabling. One-shot flourish must remain only in `presentPendingConquestReport(origin:)`, while arrival presentation is only entered from initial active-scene mounting. Tests lock resize/redraw against replay.

## Testing strategy

Follow HPA-360's behavior-oriented testing rule rather than freezing every node detail.

### 1. Focused pure selection tests

Add one small test file for `Country1MilestonePresentation` covering:

- 5 -> tier 1;
- 10 -> tier 2;
- 15 -> tier 3/finale;
- representative ordinary cities -> no milestone;
- deterministic selection.

Do not test arbitrary style constants as a public contract.

### 2. Representative BattleScene flow

Extend `BattleSceneTests` with focused behavior checks for the real integration:

- a milestone active scene presents the authored arrival title/flavor;
- combat continues while the arrival is visible;
- a tap while arrival is visible dismisses and is consumed before an underlying control;
- resize/redraw does not replay the arrival presentation;
- ordinary cities do not create milestone presentation;
- arrival title/subtitle frames fit and remain non-overlapping at `568×320`, `667×375`, and `320×568`;
- fresh milestone conquest presents the flourish once;
- layout reapply does not replay it;
- restored milestone report does not replay one-shot flourish;
- City 15 report exposes `Country 1 Complete` for both fresh and restored presentation;
- City 15 required label/report/Continue geometry fits at all three fixtures;
- a no-frame City 15 case follows the existing fit-failure gate rather than silently hiding required text;
- Continue remains actionable through the existing transaction and route.

Use DEBUG accessors only for semantic state/count/text/frame assertions needed to prove these behaviors. Avoid broad snapshots of private node trees.

### 3. Existing regression coverage

Existing BattleScene conquest-report, Settings/modal precedence, layout, fresh/restored effect, and routing tests must remain green.

### 4. Manual smoke

Run a City 5 -> City 10 -> City 15 milestone smoke covering:

- clear visual escalation;
- readable short-landscape and narrow-portrait layouts;
- arrival auto-dismiss and tap-to-skip behavior;
- skip tap never activates an underlying control;
- fresh live/idle conquest presentation;
- City 15 `Country 1 Complete` readability and Continue behavior;
- Reduce Motion enabled;
- static enemy-city accent (no looping pulse);
- no gameplay/reward/progression differences from ordinary cities.

## Expected production scope

The default implementation should fit within:

- one small new production file for milestone selection;
- `BattleScene.swift` for scene-owned presentation/lifecycle/input integration;
- focused tests in one new selector test file plus `BattleSceneTests.swift`;
- a short `CLAUDE.md` ownership note only if needed to prevent future persistence/framework drift.

No `project.pbxproj` change should be necessary when using the repository's synchronized Xcode groups.

If implementation starts requiring a presentation manager, new persistence, a generalized layout layer, several reusable node types, new assets, or more than a few production files, reduce scope before proceeding.

## Acceptance criteria

- Only Cities 5, 10, and 15 receive milestone treatment.
- Milestone text comes from the shared city definition; there is no parallel city-name/message switch.
- City 5, 10, and 15 presentation escalates clearly while reusing the same simple treatment.
- Arrival banner is non-modal, auto-dismisses, may be skipped by one consumed tap, and does not replay from resize/redraw in the mounted scene.
- Arrival required text fits at `568×320`, `667×375`, and `320×568`.
- Enemy-city accent is static in HPA-390, changes presentation only, and does not alter combat geometry or interaction.
- Fresh live/idle milestone conquest shows a one-shot flourish; restored reports do not replay the one-shot effect.
- City 15 clearly shows `Country 1 Complete` before the existing Continue route returns to the completed map.
- If City 15 completion text cannot fit, the existing unsupported-geometry gate is used; the label is never silently omitted.
- City 15 report treatment fits at `568×320`, `667×375`, and `320×568` without obscuring required report content or Continue.
- Reduced Motion preserves all milestone meaning with static/fade-only treatment.
- No gameplay mutation, reward calculation, progression rule, idle behavior, save schema, or durable consumed-presentation state changes.
- Focused selection and representative BattleScene behavior tests pass, followed by full unit/UI/lint verification and the manual milestone smoke.

## Implementation boundary summary

HPA-390 remains a thin BattleScene presentation slice:

`current city -> tiny milestone selector -> scene-owned arrival/static city accent -> existing fresh/restored conquest boundary -> scene-owned report flourish + City 15 required label`

Everything else remains owned by the systems already in `main`.