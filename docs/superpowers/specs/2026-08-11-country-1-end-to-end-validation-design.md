# HPA-567 — Country 1 End-to-End Validation Design

## Status

Planning design for HPA-567: **Validate Country 1 end to end before adding new battle mechanics**.

This is the next HPA-360 roadmap checkpoint after the three player-visible slices:

- HPA-366 — Country 1 city identity;
- HPA-365 — Recommended Camp guidance;
- HPA-390 — milestone presentation.

HPA-390's implementation is merged on `main` in PR #30. Linear still shows HPA-390 as In Progress, so the validation baseline is the merged product rather than the stale workflow label.

HPA-567 is a **human product-validation task, not an implementation task**. It must add no production code.

## Goal

Run one complete clean-save City 1 -> City 15 campaign through the current player-facing game, capture concrete friction while it happens, and use that evidence to decide whether any of the three deferred roadmap items deserve activation:

- HPA-362 — direct lane deployment experiment;
- HPA-369 — one in-memory Rally experiment;
- HPA-367 — minimal Campaign Chronicle.

The output is evidence and decisions, not another system.

## Executor contract

The campaign itself is a **human playtest**.

Agents may help only with:

- Task 1 mechanical baseline work such as checking the commit, build destination, and clean-install commands;
- Task 4 mechanical publishing of already-written evidence and decisions to Linear.

Agents must not:

- execute or simulate the City 1 -> 15 playtest;
- inspect source during the run to choose player actions;
- invent, interpolate, or rewrite missing observations;
- decide HPA-362/HPA-369/HPA-367 from architecture or implementation convenience.

Task 2 observation and Task 3 synthesis/decisions are human-owned because their value is the tester's actual experience.

## Product question

The roadmap already provides the intended casual loop:

1. understand the next city;
2. make one sensible preparation decision;
3. watch or lightly participate in the battle;
4. receive a concise, memorable conquest outcome.

HPA-567 asks whether that loop now feels sufficiently rich without more mechanics.

The playtest must distinguish four different problems instead of collapsing them into generic polish:

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

### Clean state and preferences

`KingdomGameStore` persists the campaign in `UserDefaults` under `pyxis.kingdomGameState`. `FeedbackPreferencesStore` also uses app-container `UserDefaults` under `pyxis.feedback.*`. The app bundle identifier is `cwchanap.Pyxis`.

The product-faithful reset is therefore to remove the app from the simulator/device and reinstall it. This clears both campaign state and feedback preferences without a playtest reset API.

HPA-567 must not add a reset API, launch argument, or state injector solely for the playtest.

### Campaign surfaces

Use the shipping surfaces as they exist on `main`:

- `CountryMapScene` — unlocked-city route and Scout Card;
- `CountryMapScoutCardContent.Scout` — authored city/trait/reward data plus the **exposed lane only**;
- `CountryMapTransientFeedback.completed` — current completed-city behavior is a short completion toast, not a historical report;
- `BuildingViewScene` — manual building plus `RecommendedCampRecommendation` guidance;
- `BattleScene` — battle, three visible battlefield lanes, Default Spawn/manual spawning, feedback Settings, milestone arrivals, enemy-city treatment, conquest presentation;
- `ConquestReportNode` / `ConquestReportLayout` — compact conquest result;
- `Country1CityCatalog` / `CityDefinition` — authored city identity;
- `Country1MilestoneTier` — presentation tiers for Cities 5, 10, and the finale;
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

Use one fixed build from current `main` after PR #30.

Primary device should be one ordinary supported iPhone simulator or physical iPhone using the app's normal portrait orientation. Do not run a multi-device matrix unless a blocker appears on the primary device.

Record at the top of the playtest evidence:

- commit SHA;
- device/simulator model;
- iOS version;
- starting Sound Effects state;
- starting Haptics state;
- date of the run.

### Simulator clean-install path

1. build the normal app;
2. remove `cwchanap.Pyxis` with `simctl uninstall` when installed;
3. reinstall/run the normal build;
4. confirm the app begins at the default first-city campaign state with no prior result/building/gold progress.

### Physical-device clean-install path

1. delete Pyxis from the iPhone using the normal iOS app-delete flow;
2. with the same recorded `main` commit checked out, run/install Pyxis from Xcode onto that device;
3. confirm the app begins at the same default first-city campaign state with no restored result/building/gold progress;
4. confirm Sound Effects and Haptics reflect clean-install defaults before the run begins.

If launch is broken or a previously persisted state survives app removal, stop and file a blocker. Do not add a reset feature to get around it.

## Multi-session continuity contract

City health grows exponentially (`20 * 2.15^(level-1)`), so the full campaign may naturally span hours or multiple sessions. The validation must preserve one continuous player history rather than treating each session as a new sample.

After the clean-install gate passes:

- keep the **same app installation/container** through City 15;
- keep the same installed build/commit through City 15;
- never uninstall, reinstall, reset defaults, inject state, or skip cities mid-run;
- normal background/foreground and idle progress are allowed when they happen naturally;
- if the app must be reinstalled or the build changes, the run is tainted and must restart from a fresh City 1 baseline after the blocker is resolved.

To protect long-run notes, copy the current working evidence into Linear immediately after the deep checkpoints at Cities **1, 5, and 10**. These are explicitly **working checkpoint snapshots, not conclusions**. The final City 15 result remains the canonical HPA-567 record.

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
- do not manufacture background/idle intervals, but if the run naturally spans sessions, record whether returning changes the experience;
- do not redesign a feature while playing; write down the problem first.

When uncertain, follow the most obvious player-facing action rather than consulting implementation details.

## Observation model

### Per-city run log

Record one terse row after every conquered city so the final evidence proves a complete City 1 -> City 15 run without creating research bureaucracy.

Each row contains:

| Field | Meaning |
| --- | --- |
| City | City number/name reached |
| Preparation | Main preparation choice, e.g. Recommended Camp, manual build/upgrade, no change |
| Battle input | Passive, Default Spawn, manual spawn, or other normal action actually used |
| Result impression | One short phrase about conquest/report/milestone outcome |
| Friction tag | `none`, `confusion`, `repetition`, `boredom`, `attention` — multiple only when genuinely distinct |
| Note | One concrete observation, kept short |

Do not assign numeric scores. Concrete behavior is more useful than a rating.

### Deep checkpoints

After Cities **1, 5, 10, and 15**, add a short structured checkpoint covering:

1. **Clarity** — was the next useful action understandable without a tutorial page?
2. **Repetition** — which taps or scene transitions, if any, had started to feel tedious?
3. **Battle engagement** — pleasantly passive, meaninglessly passive, or appropriately active? What caused that impression?
4. **Attention cost** — did the game create pressure to monitor, optimize, or act repeatedly?
5. **Reward and memory** — did city identity, milestones, and conquest reports make progress feel memorable?
6. **History demand** — was there a spontaneous desire to inspect a completed city or earlier result?

Cities 5/10/15 also naturally sample the milestone presentation. City 1 is the baseline checkpoint.

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
- wanting one meaningful placement choice during otherwise functioning battles -> possible HPA-362 evidence;
- wanting one satisfying active moment without wanting tactical control -> possible HPA-369 evidence.

For any bug or narrow polish issue worth tracking, file a separate Linear issue after the run with commit/device, city/context, minimal reproduction, expected behavior, and observed behavior.

## Decision outcome rule

For every deferred item, use three distinct meanings:

- **Prototype / Activate** — the full run produced concrete evidence for the problem and this specific experiment/subsystem is the clearest small fit.
- **Keep deferred** — evidence is missing or inconclusive, **or** the problem is real but this experiment/subsystem is not clearly the right solution.
- **Drop** — the relevant problem class was absent across the full run, **or** shipping UX already covers it well enough that this item would duplicate value rather than solve an unmet need.

`Drop` means actively close/remove the item from the roadmap. `Keep deferred` means leave it available for future evidence. Lack of positive evidence is not a failure; it may correctly produce either outcome under the rule above.

## Decision rubric

### HPA-362 — direct lane deployment

Choose **prototype** only when the campaign records a concrete battle-engagement problem specifically about wanting one additional tactical placement choice.

Current information is narrower than a full lane-role tutorial:

- the Scout Card exposes the city's **exposed lane**;
- the battlefield visibly renders the three lanes;
- Scout does **not** describe the full fortified/exposed/standard role set.

Therefore:

- repeated desire to choose *which visible lane* receives a manual soldier can support HPA-362;
- confusion caused only by missing fortified/standard Scout explanation is **clarity/presentation evidence**, not placement-demand evidence;
- do not activate HPA-362 merely because the Scout Card does not fully explain all lane roles.

Do not activate HPA-362 for generic slowness, unclear preparation, weak milestone presentation, or a desire for faster animation.

Apply the shared Prototype / Keep deferred / Drop rule afterward.

### HPA-369 — Rally

Choose **prototype** only when the campaign records a desire for one active emotional beat during battle without a corresponding desire for ongoing tactical micromanagement.

Good evidence looks like:

- the battle loop is understandable but emotionally flat;
- one obvious moment of agency sounds appealing;
- repeated controls, cooldown watching, or optimization would be unwelcome.

Do not activate Rally just because a battle takes time or because the feedback system can support another event.

Apply the shared outcome rule afterward.

### HPA-367 — Campaign Chronicle

Choose **activate minimal implementation** only when the campaign produces real history demand, such as:

- spontaneously tapping a completed city and wanting more than the current `"<city> complete"` transient feedback;
- wanting to remember an earlier result or unit choice;
- feeling that completed-city history is meaningfully missing from the map.

Do not force a completed-city tap just to manufacture evidence. Enjoying the conquest report by itself is not enough evidence for persistence.

Apply the shared outcome rule afterward.

### If more than one battle experiment appears supported

Do not start HPA-362 and HPA-369 together by default.

Select the experiment that most directly addresses the clearest repeated observation. Keep the other deferred unless the run contains distinct evidence that cannot be explained by the same problem.

## Evidence sink

The durable playtest record belongs in Linear, not in a new runtime subsystem or repository results store.

### Working checkpoint snapshots

After Cities 1, 5, and 10, paste the current working note into HPA-567 as a clearly labeled checkpoint snapshot. It must state that no roadmap conclusion is final yet.

These snapshots exist only to protect a long-running validation from lost notes. They do not replace the canonical final result.

### Final HPA-567 result

After City 15, add one canonical result comment containing:

- run metadata;
- all 15 city rows;
- Cities 1/5/10/15 deep checkpoints;
- campaign-wide synthesis by the six observation categories;
- explicit HPA-362/HPA-369/HPA-367 decisions using Prototype/Activate, Keep deferred, or Drop;
- links to separately filed bugs or polish issues.

### HPA-362 / HPA-369 / HPA-367

Each downstream issue receives one concise decision comment with the decision, supporting HPA-567 observations, fit analysis, and next action.

### HPA-360

Do not update the roadmap merely to summarize the playtest. Update it only when evidence actually changes roadmap priorities.

## Failure handling

- **Build/launch blocker:** stop before interpreting product behavior; file a bug.
- **Initial save/reset blocker:** stop; file a bug rather than adding a reset feature.
- **Single-city functional blocker:** record/file it separately and resume only after the normal product path is genuinely usable.
- **Required reinstall/build change after City 1:** the current validation run is invalid; restart from a new clean City 1 baseline after the blocker is resolved.
- **Temporary interruption with intact app/container:** resume the same run and continue the log.
- **Subjective dislike with no concrete behavior:** note it, but do not automatically create a feature issue.
- **No evidence for any deferred feature:** this is a valid successful validation outcome; apply Keep deferred vs Drop using the explicit outcome rule.

## Expected repository scope

The planning PR contains exactly two documentation files:

- `docs/superpowers/specs/2026-08-11-country-1-end-to-end-validation-design.md`;
- `docs/superpowers/plans/2026-08-11-country-1-end-to-end-validation-implementation.md`.

Executing HPA-567 itself should modify **no repository files**. Its durable result is recorded in Linear.

## Acceptance criteria

HPA-567 is complete when:

- one human-run clean/default-save City 1 -> City 15 campaign has been played through the normal app path;
- the same app installation and build were preserved across the full run;
- every city appears in the run log;
- Cities 1/5/10/15 have the deeper six-category observations;
- Cities 1/5/10 working checkpoint snapshots were persisted to Linear;
- findings distinguish confusion, repetition, boredom/passivity, and attention pressure;
- reward/memory and history demand are explicitly evaluated;
- HPA-362 has an evidence-backed `prototype`, `keep deferred`, or `drop` decision;
- HPA-369 has an evidence-backed `prototype`, `keep deferred`, or `drop` decision;
- HPA-367 has an evidence-backed `activate minimal implementation`, `keep deferred`, or `drop` decision;
- any newly discovered bug or narrow polish item is tracked separately;
- no production code was added as part of the validation;
- HPA-360 is changed only if the evidence actually changes roadmap priorities.
