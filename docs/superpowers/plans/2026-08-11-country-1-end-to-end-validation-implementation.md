# HPA-567 Country 1 End-to-End Validation Plan

**Goal:** Run one human clean-save City 1 -> City 15 casual campaign on a fixed current-`main` build, preserve observations across sessions, and make evidence-backed decisions for HPA-362, HPA-369, and HPA-367 without changing production code.

**Architecture:** HPA-567 is a product-validation workflow, not software architecture. The shipping app remains unchanged; the human tester uses the normal Country Map -> Building View -> Battle -> Conquest loop, records a compact evidence set, checkpoints it to Linear during the long run, and publishes the canonical result after City 15. Bugs and narrow polish are split into separate Linear issues.

**Tech Stack:** Existing Swift/SpriteKit/UIKit iOS app, Xcode/iOS Simulator or a physical iPhone, Git for baseline identification, and Linear for evidence/decisions. No new dependencies, test harnesses, telemetry, launch arguments, reset APIs, or runtime services.

## Executor contract

- **Human required:** Task 2 campaign playtest and Task 3 synthesis/roadmap decisions.
- **Agent assistance allowed:** Task 1 mechanical baseline checks and Task 4 mechanical Linear publishing after the human has written the evidence/decisions.
- Agents must not simulate the campaign, inspect source to choose player actions, invent missing notes, or infer subjective product evidence.

## Global constraints

- HPA-567 adds **no production code** and no executable tests.
- Start once from a clean/default install, then keep the same app installation/container and same installed build through City 15.
- Use the normal casual path; do not optimize from developer knowledge.
- Keep manual building and Default Spawn/manual spawning available throughout.
- Exercise Scout Card, Recommended Camp, conquest report, city identity, feedback Settings, and milestone presentation naturally.
- Record blockers separately; do not redesign or fix features during the campaign.
- Do not add analytics, telemetry, a debug reset UI, campaign skip, UI-test campaign driver, state injection, or formal scoring.
- Do not prototype HPA-362 or HPA-369 during this validation.
- The durable validation result lives in Linear. Executing HPA-567 leaves the repository unchanged.

## Current shipping facts used by the plan

- `KingdomGameStore` persists campaign state under `pyxis.kingdomGameState` in app-container `UserDefaults`.
- `FeedbackPreferencesStore` persists Sound Effects/Haptics under `pyxis.feedback.*` in the same app container.
- Bundle identifier: `cwchanap.Pyxis`.
- `CountryMapScoutCardContent.Scout` exposes the authored **exposed lane only**; it does not describe the full fortified/exposed/standard role set.
- `CountryMapTransientFeedback.completed` is the current completed-city interaction baseline: a short `"<city> complete"` transient, not history UI.
- `BattleScene` presents the current three-lane battlefield.
- City health grows as `20 * 2.15^(level-1)`, so a full campaign may naturally span multiple sessions.

---

## Task 1: Establish one trustworthy clean-install baseline

**Executor:** Human or agent-assisted mechanical setup.

**Repository changes:** none.

**Produces:** A fixed commit/build on one clean simulator or physical iPhone plus run metadata.

### Step 1: Sync and record the exact baseline commit

```bash
git switch main
git pull --ff-only
git status --short
git rev-parse HEAD
```

Required gate:

- working tree is clean;
- HEAD contains merged HPA-390 PR #30 or a later `main`;
- copy the full SHA into the working HPA-567 note.

If local work is mixed into the checkout, use a clean checkout/worktree rather than carrying it into the validation environment.

### Step 2: Choose exactly one primary target

For Simulator:

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -showdestinations
```

Prefer one current iPhone simulator such as iPhone 17 when available. Record device and iOS version.

For a physical iPhone, select that single connected device in Xcode and record its model/iOS version.

Do not create a device matrix for HPA-567.

### Step 3: Build the normal app

Simulator example:

```bash
xcodebuild \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```

For a physical device, use Xcode's normal Product -> Run flow on the recorded `main` commit.

If the normal build fails, stop and file the build failure separately. Do not treat it as product evidence.

### Step 4A: Simulator clean-install path

Boot the selected simulator and check for an existing app container:

```bash
xcrun simctl get_app_container booted cwchanap.Pyxis data
```

If installed:

```bash
xcrun simctl uninstall booted cwchanap.Pyxis
```

Then reinstall/run the normal app from Xcode or the built product.

### Step 4B: Physical-device clean-install path

On the recorded physical iPhone:

1. Delete Pyxis using the normal iOS delete-app flow.
2. Without changing the recorded `main` commit, install/run Pyxis again from Xcode.
3. Do not restore or inject app data.

This is the physical-device equivalent of the simulator uninstall path; no reset feature is needed.

### Step 5: Verify default state before starting City 1

Confirm by observation:

- no restored conquest report;
- campaign begins at the normal first-city state;
- no prior building/city progress is visible;
- no prior accumulated gold is visible;
- Sound Effects and Haptics reflect clean-install defaults.

If previous state survives app deletion, stop and file a persistence/reset blocker.

### Step 6: Create the working evidence header

Use:

```markdown
## Country 1 validation run

- Commit: <full SHA>
- Device: <simulator or physical device model>
- iOS: <version>
- Starting Sound Effects: <on/off>
- Starting Haptics: <on/off>
- Date started: <YYYY-MM-DD>
- Save state: clean/default install
- Continuity rule: same installation + same build through City 15
```

Do not publish a feature conclusion yet.

### Step 7: Freeze the validation environment

After City 1 begins:

- do not uninstall/reinstall Pyxis;
- do not reset `UserDefaults`;
- do not install a newer build;
- do not switch the running validation to another device;
- do not inject state or skip cities.

Normal app backgrounding/foregrounding and natural idle time are allowed.

If a blocker forces reinstall or a different build, discard this run as a decision gate, fix/file the blocker separately, and restart HPA-567 from a new clean City 1 baseline.

---

## Task 2: Human-run City 1 -> City 15 campaign

**Executor:** Human only.

**Repository changes:** none.

**Produces:** A complete 15-city log, four deep checkpoints, and durable working snapshots after Cities 1/5/10.

### Step 1: Prepare the city-by-city table before playing

```markdown
### City-by-city run log

| City | Preparation | Battle input | Result impression | Friction | Concrete note |
| --- | --- | --- | --- | --- | --- |
| 1 | | | | | |
| 2 | | | | | |
| 3 | | | | | |
| 4 | | | | | |
| 5 | | | | | |
| 6 | | | | | |
| 7 | | | | | |
| 8 | | | | | |
| 9 | | | | | |
| 10 | | | | | |
| 11 | | | | | |
| 12 | | | | | |
| 13 | | | | | |
| 14 | | | | | |
| 15 | | | | | |
```

For `Friction`, use only `none`, `confusion`, `repetition`, `boredom`, `attention`, or a comma-separated combination when two distinct problems occurred.

Do not use numeric ratings.

### Step 2: Follow the same casual behavior contract for every city

For each unlocked city:

1. Read the Scout Card before entry.
2. Enter through the normal map action.
3. Use Building View only when it looks useful.
4. Consider Recommended Camp when visible; follow it when it feels sensible, otherwise use manual building naturally.
5. Fight through the normal Battle Scene.
6. Use Default Spawn/manual spawning only when it feels naturally useful; do not maintain an expert spawn cadence.
7. Read the conquest report before continuing.
8. Record the city row immediately after conquest/return to the map.

Do not inspect source, tests, formulas, or hidden state between cities.

### Step 3: Record the City 1 deep checkpoint

Append:

```markdown
### Deep checkpoint — City 1

- Clarity: <concrete sentence>
- Repetition: <concrete sentence>
- Battle engagement: <pleasantly passive / meaninglessly passive / appropriately active, with reason>
- Attention cost: <concrete sentence>
- Reward and memory: <concrete sentence>
- History demand: <concrete sentence>
```

Every field needs an observed sentence; `No issue observed` is valid.

### Step 4: Persist the City 1 working snapshot to Linear

Paste the current evidence into HPA-567 as a comment headed:

```markdown
## Working checkpoint — after City 1

Partial validation evidence only. No HPA-362/HPA-369/HPA-367 decision is final yet.
```

Include the run metadata, City 1 row, and City 1 deep checkpoint.

This checkpoint is durability protection, not the canonical final result.

### Step 5: Continue Cities 2-4

Keep one row per city and write the problem before thinking about a solution.

Useful distinction:

- `repetition` — a working transition/tap becomes tedious;
- `confusion` — the player cannot tell what action/state means;
- `boredom` — the functioning battle leaves the player wanting meaningful engagement;
- `attention` — the game pressures repeated monitoring/input.

### Step 6: Record City 5 deep checkpoint and milestone impression

Use the same six fields as City 1, plus one sentence on whether the first milestone treatment makes City 5 feel meaningfully different from Cities 2-4.

Broken/overlapping milestone presentation is a bug. `I noticed it but it added little` is product evidence.

### Step 7: Persist the City 5 working snapshot to Linear

Post a second checkpoint headed:

```markdown
## Working checkpoint — after City 5

Partial validation evidence only. No deferred-item decision is final yet.
```

Paste the run metadata, Cities 1-5 rows, and City 1/5 deep checkpoints.

Never uninstall/reset the app between sessions after this point.

### Step 8: Continue Cities 6-9 and exercise feedback Settings once

Continue normal play. When it does not interrupt a critical moment, open the existing Settings surface, inspect Sound Effects/Haptics, make at most one preference change if useful, then return to the campaign.

Record only product-relevant observations; this is not a broad Settings/accessibility regression pass.

### Step 9: Record City 10 deep checkpoint

Use the six fields plus one sentence on whether the second milestone remains special or has become repetitive.

Also record which statement best matches the observed battle experience:

- still pleasantly passive;
- repeatedly wanting to choose a lane for a manual spawn;
- repeatedly wanting one satisfying active moment;
- wanting neither;
- unclear because lane/battle information itself is insufficient.

Do not choose the final HPA-362/HPA-369 outcome yet.

### Step 10: Persist the City 10 working snapshot to Linear

Post:

```markdown
## Working checkpoint — after City 10

Partial validation evidence only. Final decisions wait until City 15.
```

Paste metadata, Cities 1-10 rows, and City 1/5/10 deep checkpoints.

### Step 11: Continue Cities 11-14 across normal sessions as needed

If the campaign naturally spans background/foreground sessions, keep the same installed app/build and record whether returning after idle progress feels clearer, more rewarding, or more confusing.

Do not manufacture idle intervals solely for coverage.

### Step 12: Record City 15 / finale deep checkpoint

```markdown
### Deep checkpoint — City 15 / finale

- Clarity: <sentence>
- Repetition: <sentence>
- Battle engagement: <sentence>
- Attention cost: <sentence>
- Reward and memory: <sentence>
- History demand: <sentence>
- Finale treatment: <did City 15 feel like a meaningful campaign ending, and why?>
```

On the completed map, notice only **spontaneous** history behavior. Do not tap completed cities just to manufacture Chronicle demand.

If you naturally tap a completed city, the shipping baseline is the current short `"<city> complete"` feedback. Wanting richer information after encountering that behavior is valid Chronicle evidence.

### Step 13: Verify the human evidence is complete

Before synthesis, confirm:

```text
[ ] Same app installation/container was kept from City 1 through City 15.
[ ] Same installed build/commit was kept from City 1 through City 15.
[ ] All 15 city rows are filled.
[ ] Cities 1/5/10/15 contain all six deep-checkpoint categories.
[ ] Working checkpoint snapshots were pasted to Linear after Cities 1/5/10.
[ ] Any natural multi-session/background behavior was noted without manufacturing it.
```

Do not synthesize feature decisions from an incomplete or continuity-broken run.

---

## Task 3: Human synthesis and three explicit decisions

**Executor:** Human only.

**Repository changes:** none.

**Produces:** Campaign-wide problem synthesis and one unambiguous outcome for HPA-362, HPA-369, HPA-367.

### Step 1: Synthesize problems before solutions

Fill:

```markdown
### Campaign-wide synthesis

- Clarity: <dominant observed pattern + examples>
- Repetition: <dominant observed pattern + examples>
- Battle engagement: <dominant observed pattern + examples>
- Attention cost: <dominant observed pattern + examples>
- Reward and memory: <dominant observed pattern + examples>
- History demand: <dominant observed pattern + examples>
```

Do not name a proposed feature until the problem statement is written.

### Step 2: Separate functional defects

Create:

```markdown
### Separate blockers / polish

- None observed
```

Replace the default only for concrete reproducible issues. Record city/context, reproduction, expected behavior, and observed behavior.

A bug is not evidence that another mechanic is needed.

### Step 3: Apply the shared outcome rule

Use these meanings consistently:

- **PROTOTYPE / ACTIVATE MINIMAL IMPLEMENTATION** — a repeated problem is evidenced and this item is the clearest small fit.
- **KEEP DEFERRED** — evidence is missing/inconclusive, or the problem is real but this item is not clearly the right fit.
- **DROP** — the relevant problem class was absent across the complete run, or shipping UX already covers it well enough that this item would duplicate value.

`DROP` means close/remove the item from the roadmap. `KEEP DEFERRED` means leave it in Backlog for future evidence.

Do not use a combined `KEEP DEFERRED / DROP` outcome.

### Step 4: Decide HPA-362 — direct lane deployment

Choose `PROTOTYPE`, `KEEP DEFERRED`, or `DROP`.

Prototype only when the observed desire is specifically to choose **which visible battlefield lane receives a manual soldier**.

Interpret current lane information correctly:

- Scout provides the **exposed lane only**;
- Battle presents the three physical lanes;
- Scout does not explain the full fortified/exposed/standard role set.

Therefore, `I do not understand fortified/standard because Scout does not explain them` is a clarity/presentation issue, **not** evidence for direct placement.

Do not activate HPA-362 for generic battle slowness, unclear preparation, missing lane explanation, weak milestones, or animation pacing.

Write:

```markdown
- HPA-362: <PROTOTYPE | KEEP DEFERRED | DROP>
  - Evidence: <specific city observations>
  - Problem this would solve: <one sentence>
  - Fit: <why lane placement specifically is or is not the right response>
```

### Step 5: Decide HPA-369 — Rally

Choose `PROTOTYPE`, `KEEP DEFERRED`, or `DROP`.

Prototype only when battles are understandable but repeatedly feel emotionally flat and one obvious active moment would help without ongoing micromanagement or attention pressure.

Do not activate Rally merely because battles take time.

Write:

```markdown
- HPA-369: <PROTOTYPE | KEEP DEFERRED | DROP>
  - Evidence: <specific city observations>
  - Problem this would solve: <one sentence>
  - Fit: <why one Rally moment is or is not the right response>
```

### Step 6: Resolve HPA-362 versus HPA-369

If both initially look like `PROTOTYPE`, compare the evidence.

Prototype both only if the run contains two genuinely distinct, repeated unmet problems. Otherwise choose the experiment that directly addresses the clearer problem and apply `KEEP DEFERRED` or `DROP` to the other using the shared outcome rule.

Never use `prototype both to see` as the reason.

### Step 7: Decide HPA-367 — Campaign Chronicle

Choose `ACTIVATE MINIMAL IMPLEMENTATION`, `KEEP DEFERRED`, or `DROP`.

Activate only when the tester naturally wants completed-city history: e.g. wants a prior result, tries a completed city expecting history, or finds the current completion-only transient materially insufficient.

Do not activate Chronicle merely because conquest reports are enjoyable.

Write:

```markdown
- HPA-367: <ACTIVATE MINIMAL IMPLEMENTATION | KEEP DEFERRED | DROP>
  - Evidence: <specific history-demand observations>
  - Problem this would solve: <one sentence>
  - Fit: <why a compact completed-city history card is or is not the right response>
```

### Step 8: Produce the final decision block

Every decision must cite observed behavior, not architecture opportunity. `No evidence` is a valid reason only after it is mapped through the Keep deferred vs Drop rule.

---

## Task 4: Publish the final human-written evidence to Linear

**Executor:** Human or agent-assisted mechanical publishing.

**Repository changes:** none.

**Consumes:** Completed human Task 2 evidence and human Task 3 decisions. Agents must copy faithfully; they must not fill gaps or alter the decision logic.

### Step 1: Publish one canonical HPA-567 result comment

After City 15, publish in this order:

1. run metadata;
2. complete 15-city table;
3. City 1/5/10/15 deep checkpoints;
4. campaign-wide synthesis;
5. blockers/polish list;
6. final HPA-362/HPA-369/HPA-367 decisions.

Head it:

```markdown
## Country 1 validation — final result

Canonical result for HPA-567. Earlier City 1/5/10 checkpoint comments are partial snapshots only.
```

### Step 2: Publish the HPA-362 decision comment

```markdown
## HPA-567 decision

**Decision:** <Prototype | Keep deferred | Drop>

**Evidence:** <specific HPA-567 observations>

**Fit:** <why direct lane placement specifically does or does not address the observed problem; Scout exposes only the exposed lane>

**Next action:** <prototype this issue | leave in Backlog | close/drop>
```

Do not expand HPA-362 scope while recording the decision.

### Step 3: Publish the HPA-369 decision comment

```markdown
## HPA-567 decision

**Decision:** <Prototype | Keep deferred | Drop>

**Evidence:** <specific HPA-567 observations>

**Fit:** <why one Rally moment specifically does or does not address the observed problem>

**Next action:** <prototype this issue | leave in Backlog | close/drop>
```

### Step 4: Publish the HPA-367 decision comment

```markdown
## HPA-567 decision

**Decision:** <Activate minimal implementation | Keep deferred | Drop>

**Evidence:** <specific HPA-567 history-demand observations>

**Fit:** <why the current completion-only map feedback is sufficient or why a compact history card is needed>

**Next action:** <activate this issue | leave in Backlog | close/drop>
```

Do not broaden Chronicle into replay, achievements, timelines, or analytics.

### Step 5: File concrete blockers/polish separately

For each retained issue:

```markdown
## Context

Found during HPA-567 Country 1 validation on <commit> / <device>.

## Reproduction

1. <step>
2. <step>
3. <step>

## Expected

<expected player-visible behavior>

## Observed

<actual player-visible behavior>

## Scope

Fix this behavior only. Do not use the issue to redesign unrelated campaign mechanics.
```

Link each follow-up from the final HPA-567 result.

### Step 6: Update HPA-360 only if evidence changes priorities

Update/comment HPA-360 only when HPA-567 activates or explicitly drops a child in a way that changes roadmap priorities.

If the result simply keeps existing items deferred, leave HPA-360 unchanged.

### Step 7: Final acceptance check

```text
[ ] Human completed City 1 -> City 15 on one installation/build.
[ ] All 15 rows are filled.
[ ] City 1/5/10/15 deep checkpoints are complete.
[ ] City 1/5/10 working snapshots exist in Linear.
[ ] Confusion, repetition, boredom/passivity, attention pressure are distinguished.
[ ] Reward/memory and history demand are covered.
[ ] HPA-362 outcome is exactly Prototype, Keep deferred, or Drop.
[ ] HPA-369 outcome is exactly Prototype, Keep deferred, or Drop.
[ ] HPA-367 outcome is exactly Activate minimal implementation, Keep deferred, or Drop.
[ ] Keep deferred vs Drop follows the explicit rule.
[ ] Bugs/polish are separate issues.
[ ] HPA-360 changed only if roadmap priorities changed.
[ ] No production/test/project files changed during execution.
```

Only then should HPA-567 move to Done.

### Step 8: Verify the repository stayed untouched

```bash
git status --short
```

Expected: no changes created by executing HPA-567.

If local temporary notes exist, make sure their evidence is durable in Linear, then remove the temporary files rather than committing a playtest-results subsystem.

---

## Plan self-review

### Review-feedback coverage

- Human owns Task 2 and Task 3; agent scope is limited to mechanical Task 1/4 assistance.
- Keep deferred and Drop are separate outcomes with explicit criteria.
- Multi-session continuity keeps one installation/build and protects notes with City 1/5/10 Linear snapshots.
- Physical-device delete/reinstall/default-state steps are explicit.
- HPA-362 rubric matches shipping Scout behavior: exposed lane only, not a full lane-role explanation.

### Scope check

This remains one validation workflow. No production code, reset API, harness, telemetry, scoring model, or durable results store is introduced.
