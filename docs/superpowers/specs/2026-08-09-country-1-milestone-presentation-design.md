# HPA-390 — Country 1 Milestone Presentation Design

## Status

Approved design for HPA-390: **Add presentation-only milestone treatment for Cities 5, 10, and 15**.

HPA-390 is the next player-visible HPA-360 roadmap slice. HPA-366 (Country 1 city identity) and HPA-365 (Recommended Camp guidance) are complete, while HPA-567 remains the campaign-validation checkpoint after HPA-390.

This design intentionally keeps milestone behavior presentation-only. It does not change combat, rewards, progression, persistence, buildings, lane rules, unit rules, or idle progress.

### Relationship to HPA-366

HPA-366 intentionally left overall country completion on the Country Map after Continue and kept the City 15 Battle report title as `Crownspire Keep Falls`. HPA-390 explicitly supersedes only that earlier presentation constraint by adding a visible `Country 1 Complete` state to the City 15 report presentation before Continue.

The authored conquest title remains `Crownspire Keep Falls`, and the existing pending-result acknowledgement, save, and Country Map routing transaction remains unchanged.

## Goals

Make Cities 5, 10, and 15 feel like increasingly important Country 1 moments while preserving Pyxis's simple casual loop.

Each milestone gets:

1. A short arrival banner using the existing authored city identity.
2. A modest decorative accent around the existing enemy-city presentation.
3. A fresh-conquest flourish around the existing conquest report.

City 15 additionally makes `Country 1 Complete` explicit before Continue returns to the completed country map.

The implementation must stay small enough that removing or revising the presentation later is cheap.

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
- Fresh reports already receive a one-shot gold burst, while restored reports intentionally do not replay that effect.
- `ConquestReportLayout` already computes the safe report panel and Continue geometry.
- `ConquestReportNode` already owns the report content and Continue hit target.

HPA-390 should extend those scene-local presentation seams instead of creating a second presentation subsystem.

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

- City 5: thin/static accent;
- City 10: stronger stroke/glow treatment;
- City 15: strongest frame/glow treatment.

The same basic shape/effect is reused at all three tiers. Escalation comes from a few fixed stroke/alpha/scale constants, not separate implementations.

The accent may use a subtle pulse when Reduce Motion is off. With Reduce Motion on it remains static or fade-only.

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

### City 15 country-complete state

For City 15 fresh and restored reports, display a clear `Country 1 Complete` label associated with the report presentation.

The label is semantic state, not a one-shot animation, so it remains visible when a pending City 15 report is restored.

Keep it outside the report's existing summary rows rather than expanding `ConquestReportContent` to five rows or changing achievement semantics. Position it from the computed report/safe frames so it remains inside the safe area and does not overlap the report content or Continue.

Continue remains the existing `ConquestReportNode` control and follows the existing acknowledge -> save -> Country Map route. HPA-390 adds no alternate completion transaction.

## Motion and accessibility

Use `UIAccessibility.isReduceMotionEnabled` at presentation time.

Normal motion may use only short, non-looping emphasis such as fade/scale/pulse. Reduced-motion behavior uses static framing and fades only.

All milestone meaning is carried by text:

- arrival city title + flavor;
- existing conquest title;
- `Country 1 Complete` for City 15.

Animation, glow, and color are reinforcement only.

Do not introduce a persisted motion setting, dependency protocol, manager, or accessibility subsystem for this ticket. Reduced-motion behavior is verified manually in the HPA-390 smoke unless an existing test seam makes automated verification essentially free.

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

Arrival banner:

- fits within the current safe/content width;
- both text lines remain contained and non-overlapping;
- does not require moving existing HUD or battle controls.

Enemy-city accent:

- follows the actual rendered city frame;
- changes no battlefield geometry.

Conquest flourish / City 15 label:

- derives from the already-computed `ConquestReportLayout` safe/panel frames;
- remains within the safe area;
- does not intersect required report text or Continue;
- never changes the existing Continue hit frame.

If required milestone text cannot meet the existing supported-layout minimums, use the repository's existing fit/layout-gate behavior rather than silently clipping required text.

## Error handling

There is no new persistence or external I/O.

- Ordinary or out-of-scope cities simply have no milestone selection.
- Catalog text continues to use the existing HPA-366 lookup/fallback behavior.
- If the conquest report itself cannot fit, the existing BattleScene unsupported-geometry path remains authoritative; do not create a milestone-specific error mode.
- Decorative accent failure must never block combat or Continue.

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
- a tap while arrival is visible dismisses and is consumed before an underlying control;
- resize/redraw does not replay the arrival presentation;
- ordinary cities do not create milestone presentation;
- fresh milestone conquest presents the flourish once;
- layout reapply does not replay it;
- restored milestone report does not replay one-shot flourish;
- City 15 report exposes `Country 1 Complete` for both fresh and restored presentation;
- Continue remains actionable through the existing transaction and route.

Use DEBUG accessors only for semantic state/count/text/frame assertions needed to prove these behaviors. Avoid broad snapshots of private node trees.

### 3. Existing regression coverage

Existing BattleScene conquest-report, Settings/modal precedence, layout, fresh/restored effect, and routing tests must remain green.

### 4. Manual smoke

Run a City 5 -> City 10 -> City 15 milestone smoke covering:

- clear visual escalation;
- readable compact/short layouts;
- arrival auto-dismiss and tap-to-skip behavior;
- skip tap never activates an underlying control;
- fresh live/idle conquest presentation;
- City 15 `Country 1 Complete` readability and Continue behavior;
- Reduce Motion enabled;
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
- Enemy-city accent changes presentation only and does not alter combat geometry or interaction.
- Fresh live/idle milestone conquest shows a one-shot flourish; restored reports do not replay the one-shot effect.
- City 15 clearly shows `Country 1 Complete` before the existing Continue route returns to the completed map.
- Flourish/finale presentation does not obscure required report content or alter/block Continue.
- Reduced Motion preserves all milestone meaning with static/fade-only treatment.
- No gameplay mutation, reward calculation, progression rule, idle behavior, save schema, or durable consumed-presentation state changes.
- Focused selection and representative BattleScene behavior tests pass, followed by full unit/UI/lint verification and the manual milestone smoke.

## Implementation boundary summary

HPA-390 is intentionally a thin BattleScene presentation slice:

`current city -> tiny milestone selector -> scene-owned arrival/accent -> existing fresh/restored conquest boundary -> scene-owned report flourish`

Everything else remains owned by the systems already in `main`.
