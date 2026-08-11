# HPA-567 Country 1 End-to-End Validation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run a clean-save City 1 -> City 15 casual campaign on current `main`, record concrete product friction, and make evidence-backed decisions for HPA-362, HPA-369, and HPA-367 without changing production code.

**Architecture:** HPA-567 is a validation workflow rather than software architecture. The shipping app remains unchanged; the tester uses the normal Country Map -> Building View -> Battle -> Conquest loop, records a small structured observation set, and publishes the durable result in Linear. Bugs and follow-up polish are split into separate issues rather than fixed during the run.

**Tech Stack:** Existing Swift/SpriteKit/UIKit iOS app, Xcode/iOS Simulator or a physical iPhone, Git for baseline identification, and Linear for evidence/decisions. No new dependencies, test harnesses, telemetry, launch arguments, or runtime services.

## Global Constraints

- HPA-567 must add **no production code**.
- Start from a clean/default save.
- Use the normal casual path; do not optimize from developer knowledge.
- Keep manual building and Default Spawn/manual spawning available throughout.
- Exercise Scout Card, Recommended Camp, conquest report, city identity, feedback Settings, and milestone presentation through the shipping UI.
- Record blockers separately; do not redesign or fix features during the campaign.
- Do not add analytics, telemetry, a debug reset UI, a campaign skip, a UI-test campaign driver, or a formal scoring system.
- Do not start both HPA-362 and HPA-369 by default; each requires distinct recorded evidence.
- The durable validation result lives in Linear. Executing this plan should leave the repository unchanged.

---

## File and system map

**Repository files to read only:**

- `CLAUDE.md` — build/test commands and current architecture ownership.
- `Pyxis/KingdomGameStore.swift` — confirms normal persistence is `UserDefaults` under `pyxis.kingdomGameState`.
- `Pyxis.xcodeproj/project.pbxproj` — confirms app bundle identifier `cwchanap.Pyxis` and normal portrait orientation.
- `Pyxis/CountryMapScene.swift` — current map/Scout path.
- `Pyxis/BuildingViewScene.swift` — current manual-building and Recommended Camp path.
- `Pyxis/BattleScene.swift` — current battle, Settings, milestone, and conquest flow.

**Repository files to modify during HPA-567 execution:** none.

**External records to modify after the playtest:**

- Linear HPA-567 — full campaign evidence.
- Linear HPA-362 — lane-deployment decision comment.
- Linear HPA-369 — Rally decision comment.
- Linear HPA-367 — Chronicle decision comment.
- New Linear bug/polish issues only when the run produces concrete, separately actionable findings.
- Linear HPA-360 only if the evidence actually changes roadmap priorities.

---

### Task 1: Establish a trustworthy clean-save baseline

**Files:**
- Read: `CLAUDE.md`
- Read: `Pyxis/KingdomGameStore.swift`
- Read: `Pyxis.xcodeproj/project.pbxproj`
- Modify: none

**Produces:** A normal shipping build on a clean/default save, plus the exact run metadata needed to interpret later observations.

- [ ] **Step 1: Sync to current `main` and record the commit**

```bash
git switch main
git pull --ff-only
git status --short
git log -1 --oneline
```

Expected:

- working tree is clean;
- HEAD includes the merged HPA-390 work from PR #30 or a later `main` commit;
- record the full SHA with:

```bash
git rev-parse HEAD
```

If the working tree is not clean, do not mix unrelated local work into the validation environment. Use a clean worktree/checkout before continuing.

- [ ] **Step 2: Confirm an available simulator destination**

```bash
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -showdestinations
```

Choose one ordinary supported iPhone simulator. Prefer `iPhone 17` when available because CI already uses it; otherwise use one current iPhone destination and record its model/iOS version.

Do not create a multi-device matrix for HPA-567.

- [ ] **Step 3: Build the normal app**

Using iPhone 17 when available:

```bash
xcodebuild \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```

Expected: build exits 0.

If the build fails, stop the product-validation run and file the build failure separately. Do not interpret build breakage as gameplay evidence.

- [ ] **Step 4: Clear the persisted campaign without adding reset code**

Boot the chosen simulator, then check whether Pyxis is installed:

```bash
xcrun simctl get_app_container booted cwchanap.Pyxis data
```

If the command returns an app container, remove the app:

```bash
xcrun simctl uninstall booted cwchanap.Pyxis
```

If `get_app_container` reports that the app is not installed, the simulator is already clean for this bundle identifier.

Reinstall/launch the normal app from Xcode or the built product. Do not add a launch argument, reset button, or state-injection helper.

- [ ] **Step 5: Verify the default state by observation**

Launch Pyxis and confirm:

- there is no restored pending conquest report;
- the campaign begins at its normal first-city/default state;
- no previous gold/building/city progress is visible.

If prior progress survives app removal, stop and file a persistence/reset blocker. Do not work around it with playtest-only production code.

- [ ] **Step 6: Start the HPA-567 evidence note with run metadata**

Prepare this exact heading for the eventual HPA-567 Linear result comment:

```markdown
## Country 1 validation run

- Commit: `<full SHA>`
- Device: `<simulator or physical device>`
- iOS: `<version>`
- Starting Sound Effects: `<on/off>`
- Starting Haptics: `<on/off>`
- Date: `<YYYY-MM-DD>`
- Save state: clean/default install
```

Do not publish a partial conclusion yet; keep this as the working evidence record until Task 4.

---

### Task 2: Run City 1 -> City 15 through the normal casual loop

**Files:**
- Modify: none

**Consumes:** The clean/default build and run metadata from Task 1.

**Produces:** A 15-row campaign log plus deeper observations at Cities 1, 5, 10, and 15.

- [ ] **Step 1: Create the 15-city run-log skeleton before playing**

Use this table in the working HPA-567 note:

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

For `Friction`, use only `none`, `confusion`, `repetition`, `boredom`, `attention`, or a comma-separated combination when two genuinely distinct problems occurred.

Do not use numeric ratings.

- [ ] **Step 2: Follow the same behavior contract for every city**

For each unlocked city:

1. Read the Scout Card before entry.
2. Enter through the normal map action.
3. Use Building View when it looks useful; do not open it only to satisfy a checklist.
4. Consider Recommended Camp when visible. Follow it when it makes sense to a casual player; choose manual building when that is the natural decision.
5. Fight through the normal Battle Scene.
6. Use Default Spawn/manual spawning only when it feels naturally useful; do not maintain an expert spawn cadence.
7. Read the conquest report before continuing.
8. Record the row immediately after conquest/return to the map.

Do not inspect source or formulas between cities to optimize the run.

- [ ] **Step 3: Record City 1 deep checkpoint**

After City 1, append:

```markdown
### Deep checkpoint — City 1

- Clarity: <what made the next useful action clear or unclear>
- Repetition: <none yet, or the first repeated interaction already noticed>
- Battle engagement: <pleasantly passive / meaninglessly passive / appropriately active, with reason>
- Attention cost: <whether monitoring/optimization pressure appeared>
- Reward and memory: <whether identity + result made the first conquest memorable>
- History demand: <whether there was any desire to inspect the completed city again>
```

Every field must contain a concrete sentence, including `No issue observed` when appropriate.

- [ ] **Step 4: Continue through Cities 2-4 and record one row per city**

Keep notes short. Examples of useful specificity:

```text
confusion — Scout made the trait clear, but I returned to Building View because I could not tell whether Recommended Camp was now affordable.
```

```text
repetition — map -> building -> battle felt like one extra transition by City 4 even though each screen was understandable.
```

Avoid design solutions at this stage.

- [ ] **Step 5: Record City 5 deep checkpoint**

After City 5, add the same six fields used for City 1.

Also record one sentence about whether the first milestone treatment made City 5 feel meaningfully more important than Cities 2-4. Treat a broken/overlapping milestone as a bug; treat "I noticed it but it added little" as product evidence.

- [ ] **Step 6: Continue through Cities 6-9 and record one row per city**

Pay particular attention to repetition becoming cumulative. Do not label a battle `boredom` merely because it is passive; distinguish "I was content to watch" from "I wanted something meaningful to do."

- [ ] **Step 7: Exercise feedback Settings once when it does not interrupt a critical moment**

Open the existing Settings surface through the normal UI, inspect Sound Effects and Haptics, make at most one preference change if you actually want to evaluate it, then return to the campaign.

Record only product observations that matter to the casual loop, such as:

- settings were easy/hard to find;
- the surface felt appropriately small or distracting;
- changing a preference created unexpected friction.

This is not a full accessibility/settings regression pass.

- [ ] **Step 8: Record City 10 deep checkpoint**

After City 10, add the six fields and one sentence on whether the second milestone treatment still feels special or has become repetitive.

At this point, explicitly note whether battle engagement is trending toward:

- still pleasantly passive;
- wanting a tactical placement choice;
- wanting one emotional action;
- wanting neither.

Do not choose the final HPA-362/HPA-369 decision yet; continue through City 15.

- [ ] **Step 9: Continue through Cities 11-14 and record one row per city**

If the run naturally spans background/foreground sessions, add a note to the affected row about whether returning after idle progress made the loop clearer, more rewarding, or more confusing. Do not manufacture an idle interval solely for coverage.

- [ ] **Step 10: Record City 15/finale deep checkpoint**

After the final conquest and Country 1 completion presentation, add:

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

Before leaving the completed map, notice whether you spontaneously try or want to inspect an earlier completed city. That behavior is high-value Chronicle evidence; do not manufacture it just to satisfy HPA-367.

- [ ] **Step 11: Verify the run log is complete before synthesizing**

Confirm all 15 rows have:

- a preparation entry;
- a battle-input entry;
- a result impression;
- a friction classification;
- one concrete note.

Confirm Cities 1, 5, 10, and 15 each have all six deep-checkpoint categories.

Do not proceed to conclusions with missing city rows.

---

### Task 3: Convert observations into three explicit roadmap decisions

**Files:**
- Modify: none

**Consumes:** The complete City 1 -> City 15 evidence from Task 2.

**Produces:** One explicit evidence-backed decision for HPA-362, HPA-369, and HPA-367, plus campaign-wide synthesis.

- [ ] **Step 1: Write the campaign-wide synthesis before choosing features**

Append this section and fill every line from observed behavior:

```markdown
### Campaign-wide synthesis

- Clarity: <dominant pattern and concrete example(s)>
- Repetition: <dominant pattern and concrete example(s)>
- Battle engagement: <dominant pattern and concrete example(s)>
- Attention cost: <dominant pattern and concrete example(s)>
- Reward and memory: <dominant pattern and concrete example(s)>
- History demand: <dominant pattern and concrete example(s)>
```

Do not mention a proposed solution until the problem statement is clear.

- [ ] **Step 2: Classify any functional problems separately**

Create a working list:

```markdown
### Separate blockers / polish

- <none>
```

Replace `<none>` only when there is a concrete reproducible bug or narrow polish item. For each item, record city/context, steps, expected behavior, and observed behavior so Task 4 can file it separately.

Do not use a functional bug as evidence that a new mechanic is needed.

- [ ] **Step 3: Decide HPA-362 — direct lane deployment**

Use exactly one of:

```markdown
- HPA-362: PROTOTYPE
```

or

```markdown
- HPA-362: KEEP DEFERRED / DROP
```

Choose `PROTOTYPE` only when the run contains a concrete desire for one additional tactical *placement* choice and the problem is not better explained by pacing, clarity, or presentation.

Under the decision, write:

```markdown
  - Evidence: <specific city observations>
  - Problem this would solve: <one sentence>
  - Why this is or is not the right experiment: <one sentence>
```

- [ ] **Step 4: Decide HPA-369 — Rally**

Use exactly one of:

```markdown
- HPA-369: PROTOTYPE
```

or

```markdown
- HPA-369: KEEP DEFERRED / DROP
```

Choose `PROTOTYPE` only when battles are understandable but emotionally flat and one obvious active moment would improve them without creating repeated attention pressure.

Add the same Evidence / Problem / Why structure used for HPA-362.

- [ ] **Step 5: Resolve the two battle-experiment decisions against each other**

If both HPA-362 and HPA-369 initially look like `PROTOTYPE`, compare the evidence.

Keep both only when the run contains two distinct problems. Otherwise activate the experiment that most directly addresses the clearer repeated problem and return the other to `KEEP DEFERRED / DROP`.

The default result must not be "prototype both to see."

- [ ] **Step 6: Decide HPA-367 — Campaign Chronicle**

Use exactly one of:

```markdown
- HPA-367: ACTIVATE MINIMAL IMPLEMENTATION
```

or

```markdown
- HPA-367: KEEP DEFERRED / DROP
```

Choose activation only when the run records real history demand: trying/wanting to inspect a completed city, wanting an earlier result, or feeling completed-city history is meaningfully missing.

Add the same Evidence / Problem / Why structure.

Do not activate Chronicle merely because the conquest reports are enjoyable.

- [ ] **Step 7: Produce the final decisions block**

Append:

```markdown
### Deferred-item decisions

- HPA-362: <PROTOTYPE or KEEP DEFERRED / DROP>
  - Evidence: <specific observation(s)>
  - Problem this would solve: <sentence>
  - Why this is/is not the right experiment: <sentence>

- HPA-369: <PROTOTYPE or KEEP DEFERRED / DROP>
  - Evidence: <specific observation(s)>
  - Problem this would solve: <sentence>
  - Why this is/is not the right experiment: <sentence>

- HPA-367: <ACTIVATE MINIMAL IMPLEMENTATION or KEEP DEFERRED / DROP>
  - Evidence: <specific observation(s)>
  - Problem this would solve: <sentence>
  - Why this is/is not the right subsystem: <sentence>
```

Every decision must cite observed behavior, not architecture opportunity.

---

### Task 4: Publish evidence to Linear and split follow-ups cleanly

**Files:**
- Modify: none

**Consumes:** The completed evidence and decisions from Task 3.

**Produces:** HPA-567 contains the full validation record; HPA-362/HPA-369/HPA-367 each contain an evidence-backed decision; concrete bugs/polish are separately tracked.

- [ ] **Step 1: Add the complete result as one top-level HPA-567 comment**

Publish the working note containing, in this order:

1. run metadata;
2. complete 15-city table;
3. Cities 1/5/10/15 deep checkpoints;
4. campaign-wide synthesis;
5. separate blockers/polish list;
6. deferred-item decisions.

Do not split the core run across many comments; one result comment makes the evidence easy to review later.

- [ ] **Step 2: Add the HPA-362 decision comment**

Use this exact structure:

```markdown
## HPA-567 decision

**Decision:** <Prototype | Keep deferred | Drop>

**Evidence:** <specific HPA-567 city observation(s)>

**Fit:** <why direct lane deployment specifically does or does not address the observed problem>

**Next action:** <prototype this issue | leave in Backlog | close/drop>
```

Link/reference HPA-567 in the comment.

Do not expand the existing HPA-362 scope while recording the decision.

- [ ] **Step 3: Add the HPA-369 decision comment**

Use the same four fields:

```markdown
## HPA-567 decision

**Decision:** <Prototype | Keep deferred | Drop>

**Evidence:** <specific HPA-567 city observation(s)>

**Fit:** <why one Rally moment specifically does or does not address the observed problem>

**Next action:** <prototype this issue | leave in Backlog | close/drop>
```

Do not add cooldowns, charges, damage buffs, or other Rally ideas to the decision comment.

- [ ] **Step 4: Add the HPA-367 decision comment**

Use:

```markdown
## HPA-567 decision

**Decision:** <Activate minimal implementation | Keep deferred | Drop>

**Evidence:** <specific HPA-567 history-demand observation(s)>

**Fit:** <why a compact completed-city history card does or does not address the observed demand>

**Next action:** <activate this issue | leave in Backlog | close/drop>
```

Do not broaden Chronicle into replay, achievements, timelines, or analytics.

- [ ] **Step 5: File each concrete blocker or narrow polish item separately**

For every item retained in `Separate blockers / polish`, create a separate Linear issue with this minimum description:

```markdown
## Context

Found during HPA-567 Country 1 validation on `<commit>` / `<device>`.

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

Link the new issue from the HPA-567 result comment or add a short follow-up reply containing the issue link.

- [ ] **Step 6: Update HPA-360 only when priorities actually change**

If HPA-567 activates an experiment/subsystem or supplies evidence that explicitly drops one, update/comment on HPA-360 with only the changed roadmap decision and the HPA-567 evidence reference.

If the validation simply confirms the current roadmap/deferred state, leave HPA-360 unchanged.

- [ ] **Step 7: Verify HPA-567 acceptance before marking the validation complete**

Check each item manually:

```text
[ ] City 1 -> City 15 run is fully recorded.
[ ] All 15 run-log rows are filled.
[ ] Cities 1/5/10/15 contain all six deep-checkpoint categories.
[ ] Confusion, repetition, boredom/passivity, and attention pressure are distinguished.
[ ] Reward/memory and history demand are explicitly covered.
[ ] HPA-362 has an evidence-backed decision comment.
[ ] HPA-369 has an evidence-backed decision comment.
[ ] HPA-367 has an evidence-backed decision comment.
[ ] Bugs/polish discovered during the run are separate issues.
[ ] No production/test/project files changed for the validation.
[ ] HPA-360 changed only if evidence changed roadmap priorities.
```

Only after every applicable item is satisfied should HPA-567 move to Done.

- [ ] **Step 8: Verify the repository stayed untouched by the validation**

```bash
git status --short
```

Expected: no changes created by executing HPA-567.

If temporary local notes were created, move the evidence into Linear and remove the temporary files before finishing. Do not commit the playtest log as a new runtime or product artifact unless a later explicit documentation ticket asks for it.

---

## Plan self-review

### Spec coverage

- Clean/default save: Task 1.
- Normal casual path and current feature surfaces: Task 2.
- Complete City 1 -> 15 record: Task 2.
- Clarity/repetition/battle engagement/attention/reward/history observations: Tasks 2-3.
- HPA-362/HPA-369/HPA-367 evidence gates: Task 3.
- Separate bugs/polish: Tasks 3-4.
- Linear as result sink: Task 4.
- No production code/telemetry/harness: Global Constraints + Task 4 verification.
- HPA-360 updated only on real priority change: Task 4.

### Scope check

This plan contains one product-validation workflow with four sequential reviewable stages. It introduces no independent software subsystem and therefore does not need decomposition into additional implementation plans.

### Type/interface consistency

There are no new code interfaces or persisted types. The only durable outputs are Linear comments/issues using the templates above.
