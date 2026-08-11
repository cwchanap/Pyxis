# HPA-567 — Country 1 End-to-End Validation Design

## Status

Planning design for HPA-567: **Validate Country 1 end to end before adding new battle mechanics**.

This is the next HPA-360 roadmap checkpoint after the three player-visible slices:

- HPA-366 — Country 1 city identity;
- HPA-365 — Recommended Camp guidance;
- HPA-390 — milestone presentation.

HPA-390's implementation is merged on `main` in PR #30. Linear still shows HPA-390 as In Progress, so the planning work must not assume a separate new feature is needed merely because the workflow status lags the merged code.

HPA-567 is a **product-validation task, not an implementation task**. It must add no production code.

## Goal

Run one complete clean-save City 1 -> City 15 campaign through the current player-facing game, capture concrete friction while it happens, and use that evidence to decide whether any of the three deferred roadmap items deserve activation:

- HPA-362 — direct lane deployment experiment;
- HPA-369 — one in-memory Rally experiment;
- HPA-367 — minimal Campaign Chronicle.

The output is evidence and decisions, not another system.

## Product question

The roadmap already provides the intended casual loop:

1. understand the next city;
2. make one sensible preparation decision;
3. watch or lightly participate in the battle;
4. receive a concise, memorable conquest outcome.

HPA-567 answers whether that loop now feels sufficiently rich without more mechanics.

The playtest must distinguish four different problems instead of collapsing them into generic "polish":

- **confusion** — the player cannot tell what to do next or why;
- **repetition** — repeated taps or scene transitions become tedious;
- **boredom/passivity** — the battle lacks a satisfying level of engagement;
- **attention pressure** — the game asks for more monitoring, optimization, or repeated action than a casual idle loop should require.

Reward/memory and history demand are recorded separately because they gate Chronicle rather than battle mechanics.

## Non-goals

HPA-567 does not add or change:

- production Swift code;
- tests, launch arguments, debug menus, reset buttons, or playtest-only game modes;
- analytics, telemetry, event logging, session recording infrastructure, or dashboards;
- balance formulas, rewards, combat values, building costs, spawn rules, or progression;
- lane selection, Rally, Chronicle persistence, or any other deferred feature;
- automated full-campaign UI tests;
- a usability-research framework, scoring model, or weighted rubric;
- broad accessibility, layout, or performance audits unrelated to a blocker found during the run;
- speculative follow-up work while the campaign is still in progress.

A bug found during the run is recorded separately. It is not fixed inside HPA-567.

## Existing behavior to reuse

The current repository already contains everything required for the validation run.

### Clean state

`KingdomGameStore` persists the campaign in `UserDefaults` under `pyxis.kingdomGameState`. The app bundle identifier is `cwchanap.Pyxis`.

The cleanest product-faithful reset is therefore to remove the app from the simulator/device and reinstall it. HPA-567 must not add a reset API or launch argument solely for the playtest.

### Campaign surfaces

Use the shipping surfaces as they exist on `main`:

- `CountryMapScene` — unlocked-city route and Scout Card;
- `BuildingViewScene` — manual building plus `RecommendedCampRecommendation` guidance;
- `BattleScene` — battle, Default Spawn/manual spawning, feedback Settings, milestone arrivals, enemy-city treatment, conquest presentation;
- `ConquestReportNode` / `ConquestReportLayout` — compact conquest result;
- `Country1CityCatalog` / `CityDefinition` — authored city identity;
- `KingdomGameStore` — normal persistence across sessions.

No special scene should be constructed to jump between cities.

## Approaches considered

### Approach A — one structured manual campaign — selected

Run the real game from a clean save and keep a compact observation log.

**Why this is preferred:**

- it measures the actual interaction cost of the current game;
- it preserves pacing, persistence, scene transitions, and the existing UI hierarchy;
- it produces the qualitative evidence required by HPA-362/HPA-369/HPA-367;
- it adds zero code and can be repeated later with a different build if needed.

### Approach B — automated campaign/UI-test harness — rejected

A scripted runner could prove that cities can be advanced mechanically, but it cannot answer whether a battle feels boring, whether a recommendation is understandable, or whether the player wants history.

It would also encourage shortcuts around the exact tap/transition repetition HPA-567 is meant to observe.

### Approach C — temporary telemetry/instrumentation — rejected

Instrumentation could count taps or time-in-scene, but one product-validation run does not justify a new event surface, data model, export path, or cleanup task.

The roadmap explicitly requires observed friction, not analytics infrastructure.

## Test environment

Use current `main` after PR #30.

Primary device should be one ordinary supported iPhone simulator or physical iPhone using the app's normal portrait orientation. The current Xcode project targets iPhone and iPad, with portrait orientation configured for both.

Do not rotate through a geometry matrix or run multiple devices as part of HPA-567 unless a blocker appears on the primary device.

Record at the top of the playtest evidence:

- commit SHA;
- device/simulator model;
- iOS version;
- whether Sound Effects and Haptics started enabled or disabled;
- date of the run.

## Clean-save entry gate

Before the campaign starts:

1. confirm the working build is current `main` and includes PR #30;
2. build the normal app without playtest-only changes;
3. remove `cwchanap.Pyxis` from the target simulator/device if it is installed;
4. reinstall and launch;
5. confirm the first screen reflects a default campaign state rather than a restored city/result.

If launch is broken or a previously persisted state survives app removal, stop and file a blocker. Do not add a reset feature to get around it.

## Playtest behavior contract

The tester should behave like a casual player, not like the author of the combat formulas.

During the run:

- do not inspect source, formulas, hidden state, or tests to decide the next move;
- read the Scout Card before entering the unlocked city;
- use Building View when it looks useful rather than on a forced schedule;
- consider Recommended Camp as visible assistance, but do not blindly obey it when it feels wrong;
- keep manual building available and use it when that is the natural choice;
- keep Default Spawn/manual spawning available and use it when it feels naturally useful;
- do not deliberately optimize spawn cadence, building efficiency, lane outcomes, or resource farming from developer knowledge;
- do not manufacture background/idle intervals, but if the run naturally spans sessions, record whether returning to the game changes the experience;
- do not redesign a feature while playing; write down the problem first.

When uncertain, follow the most obvious player-facing action rather than consulting implementation details.

## Observation model

### Per-city run log

Record one terse row after every conquered city so the final evidence proves a complete City 1 -> City 15 run without creating a research bureaucracy.

Each row contains:

| Field | Meaning |
| --- | --- |
| City | City number/name reached |
| Preparation | Main preparation choice, e.g. Recommended Camp, manual build/upgrade, no change |
| Battle input | Passive, Default Spawn, manual spawn, or other normal action actually used |
| Result impression | One short phrase about conquest/report/milestone outcome |
| Friction tag | `none`, `confusion`, `repetition`, `boredom`, `attention` — multiple only when genuinely distinct |
| Note | One concrete observation, kept short |

Do not assign numeric scores. A sentence such as "I opened Building View twice because I could not tell whether the recommendation had become affordable" is more useful than "clarity 3/5".

### Deep checkpoints

After Cities **1, 5, 10, and 15**, add a short structured checkpoint covering:

1. **Clarity** — was the next useful action understandable without a tutorial page?
2. **Repetition** — which taps or scene transitions, if any, had started to feel tedious?
3. **Battle engagement** — pleasantly passive, meaninglessly passive, or appropriately active? What caused that impression?
4. **Attention cost** — did the game create pressure to monitor, optimize, or act repeatedly?
5. **Reward and memory** — did city identity, milestones, and conquest reports make progress feel memorable?
6. **History demand** — was there a spontaneous desire to inspect a completed city or earlier result?

Cities 5/10/15 are already milestone cities, so the checkpoint naturally samples the presentation work without inventing a separate milestone test system.

### Event capture rule

Write observations close to when they occur. Do not wait until City 15 and reconstruct the whole campaign from memory.

Keep notes concise enough that recording them does not become the dominant interaction cost of the playtest itself.

## Separating bugs from product evidence

A functional defect is not automatically evidence for a new mechanic.

Examples:

- a button that does not respond -> bug;
- a report that overlaps required content -> bug;
- not knowing which button advances the campaign -> clarity evidence;
- tapping the same scene transition repeatedly even though it works -> repetition evidence;
- wanting one meaningful choice during otherwise functioning battles -> possible HPA-362 evidence;
- wanting one satisfying active moment without wanting tactical control -> possible HPA-369 evidence.

For any bug or narrow polish issue worth tracking, file a separate Linear issue after the run with:

- commit/device;
- city/context;
- minimal reproduction steps;
- expected behavior;
- observed behavior.

Do not fix it on the HPA-567 planning or validation branch.

## Decision rubric

HPA-567 must produce one explicit outcome for each deferred item. No item is activated merely because its implementation is technically easy.

### HPA-362 — direct lane deployment

Choose **prototype** only when the campaign records a concrete battle-engagement problem that is specifically about wanting one additional tactical placement choice.

Good evidence looks like:

- the battle feels too passive despite pacing/feedback being otherwise acceptable;
- the tester repeatedly wants to influence *where* a manual soldier goes;
- lane information already visible in the game makes such a choice feel understandable.

Do **not** activate HPA-362 for generic slowness, unclear preparation, weak milestone presentation, or a desire for faster animation.

Otherwise choose **keep deferred/drop** and cite why.

### HPA-369 — Rally

Choose **prototype** only when the campaign records a desire for one active emotional beat during battle without a corresponding desire for ongoing tactical micromanagement.

Good evidence looks like:

- the battle loop is understandable but emotionally flat;
- one obvious moment of agency sounds appealing;
- repeated controls, cooldown watching, or optimization would be unwelcome.

Do **not** activate Rally just because a battle takes time or because the feedback system can support another event.

Otherwise choose **keep deferred/drop** and cite why.

### HPA-367 — Campaign Chronicle

Choose **activate minimal implementation** only when the campaign produces real history demand, such as:

- trying to tap a completed city expecting prior information;
- wanting to remember an earlier result or unit choice;
- feeling that completed-city history is meaningfully missing from the map.

Enjoying the conquest report by itself is not enough evidence for persistence.

Otherwise choose **keep deferred/drop** and cite why.

### If more than one battle experiment appears supported

Do not start HPA-362 and HPA-369 together by default.

Select the experiment that most directly addresses the clearest repeated observation. Keep the other deferred unless the run contains distinct evidence that cannot be explained by the same problem.

This preserves the roadmap rule of at most one lightweight tactical decision.

## Evidence sink

The final playtest record belongs in Linear, not in a new runtime subsystem.

### HPA-567

Add one top-level result comment containing:

- run metadata;
- all 15 city rows;
- Cities 1/5/10/15 deep checkpoints;
- campaign-wide synthesis by the six observation categories;
- explicit HPA-362/HPA-369/HPA-367 decisions;
- links to any separately filed bugs or polish issues.

### HPA-362 / HPA-369 / HPA-367

Each downstream issue receives one concise decision comment:

- decision;
- supporting HPA-567 observation(s);
- why this experiment/subsystem does or does not address the observed problem;
- next action: prototype/activate, keep deferred, or drop.

### HPA-360

Do not update the roadmap merely to summarize the playtest. Update it only when the evidence actually changes roadmap priorities, matching HPA-567's acceptance criteria.

## Failure handling

- **Build/launch blocker:** stop before interpreting product behavior; file a bug.
- **Save/reset blocker:** stop; file a bug rather than adding a reset feature.
- **Single-city functional blocker:** record the blocker and file it separately. Resume the validation only after the product path is genuinely usable; do not invent a developer shortcut inside HPA-567.
- **Subjective dislike with no concrete behavior:** note it, but do not automatically create a feature issue.
- **No evidence for any deferred feature:** this is a valid successful validation outcome. Keep the experiments/subsystem deferred or drop them.

## Expected repository scope

The planning PR contains exactly two documentation files:

- `docs/superpowers/specs/2026-08-11-country-1-end-to-end-validation-design.md`;
- `docs/superpowers/plans/2026-08-11-country-1-end-to-end-validation-implementation.md`.

Executing HPA-567 itself should modify **no repository files**. Its durable result is recorded in Linear.

No production file, test file, asset, Xcode project file, or dependency should change.

## Acceptance criteria

HPA-567 is complete when:

- one clean/default-save City 1 -> City 15 campaign has been played through the normal app path;
- every city appears in the run log;
- Cities 1/5/10/15 have the deeper six-category observations;
- findings distinguish confusion, repetition, boredom/passivity, and attention pressure;
- reward/memory and history demand are explicitly evaluated;
- HPA-362 has an evidence-backed `prototype` or `keep deferred/drop` decision;
- HPA-369 has an evidence-backed `prototype` or `keep deferred/drop` decision;
- HPA-367 has an evidence-backed `activate minimal implementation` or `keep deferred/drop` decision;
- any newly discovered bug or narrow polish item is tracked separately;
- no production code was added as part of the validation;
- HPA-360 is changed only if the evidence actually changes roadmap priorities.
