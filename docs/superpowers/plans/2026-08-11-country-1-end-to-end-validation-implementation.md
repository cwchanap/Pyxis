# HPA-567 — Country 1 End-to-End Validation Plan

## Rationale

HPA-567 answers one product question: **after the shipped Scout Card, Recommended Camp, conquest report, city identity, feedback, and milestone work, is Country 1 already rich enough for a casual player without another mechanic or durable campaign subsystem?**

This is a human product-validation run, not an implementation task. It adds no production code, test harness, telemetry, reset API, analytics, or scoring system.

Record concrete observations under four friction classes:

- **confusion** — the next useful action or current state is unclear;
- **repetition** — working taps/transitions become tedious;
- **boredom/passivity** — a functioning battle leaves the player wanting meaningful engagement;
- **attention pressure** — the game asks for more monitoring, optimization, or repeated input than the casual loop should require.

Also record **reward/memory** and **history demand**, because those gate presentation/Chronicle decisions rather than battle mechanics.

### Why not automate it?

A UI-test campaign runner can prove progression works mechanically, but it cannot tell whether a battle is pleasantly passive, whether a recommendation feels understandable, or whether a completed city feels worth revisiting. It would also skip the exact interaction repetition being measured.

### Why not add telemetry?

One validation run does not justify a new event surface, storage/export path, cleanup task, or analytics workflow. HPA-567 needs observed product friction, not infrastructure.

---

## Executor and scope

- **Human required:** the campaign playtest and the final product synthesis/decisions.
- **Agent assistance allowed:** mechanical setup checks and faithful publishing of already-written human evidence to Linear.
- Agents must not simulate play, choose actions from source/formulas, invent missing observations, or make subjective roadmap decisions.
- The repository stays unchanged while HPA-567 executes.

Use one **iPhone Simulator** as the primary environment. Prefer iPhone 17 when available because CI already uses it. A physical device is not a second validation matrix; use one only if a blocker appears simulator-specific.

**Haptics are out of scope for this run.** The shipping haptic output depends on hardware haptic capability, so Simulator cannot provide a meaningful tactile evaluation. Sound Effects remain in scope.

---

## Shipping facts reused by the run

- Campaign persistence: `UserDefaults.standard`, key `pyxis.kingdomGameState`.
- Feedback preferences: `UserDefaults.standard`, prefix `pyxis.feedback`.
- Bundle identifier: `cwchanap.Pyxis`.
- Country 1 contains 15 cities.
- Scout exposes the authored **exposed lane only**; it does not explain the full fortified/exposed/standard role set.
- Battle shows the current three physical lanes.
- Tapping a completed city currently produces the short `"<city> complete"` transient; there is no historical report.
- Idle catch-up is building-driven, capped at 8 hours, runs at `1 / idleBuildingProductionScale`, and can conquer at most one city on one return.
- City HP grows exponentially, so a complete campaign can naturally span multiple sessions.

---

## 1. Setup — one fixed Simulator baseline

### Record the build

```bash
git switch main
git pull --ff-only
git status --short
git rev-parse HEAD
xcodebuild -project Pyxis.xcodeproj -scheme Pyxis -showdestinations
```

Record:

```markdown
## Country 1 validation run

- Commit: <full SHA>
- Simulator: <model>
- iOS: <version>
- Date started: <YYYY-MM-DD>
- Starting Sound Effects: <on/off>
- Save state: clean/default install
```

The validation baseline is the recorded **runtime content**, not whether Xcode produced a fresh binary. Rebuilding/reinstalling from the same commit is allowed. A different commit is allowed only when its diff is non-runtime documentation/metadata; any change that can affect gameplay, UI, routing, feedback, persistence, layout, or presentation creates a mixed baseline and requires a new run.

### Build the normal app

```bash
xcodebuild \
  -project Pyxis.xcodeproj \
  -scheme Pyxis \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build
```

If that exact simulator is unavailable, use the one recorded above.

### Clean install

Check/remove the current app container:

```bash
xcrun simctl get_app_container booted cwchanap.Pyxis data
xcrun simctl uninstall booted cwchanap.Pyxis
```

If Pyxis is not installed, the uninstall failure is harmless. Reinstall/run the recorded build normally.

Before City 1, verify by observation:

- no restored conquest report;
- normal first-city/default campaign state;
- no previous building/city progress;
- no previous accumulated gold;
- Sound Effects reflect the clean-install default.

If old state survives deletion, stop and file a persistence blocker rather than adding reset code.

---

## 2. Run — normal casual play, with one deliberate idle check

### Expected budget and timebox

Plan for roughly **1–3 hours of active foreground play plus note-taking**, spread across sessions if needed, **plus one deliberate overnight idle window**. This is a scheduling estimate, not a balance target.

Use two validation timeboxes:

- **20-minute city checkpoint:** after about 20 minutes of active foreground play on one unconquered city, explicitly record whether continued progress still feels acceptable to a casual player.
- **30-minute city cap:** if the same city is still unconquered after about 30 minutes of active foreground play, stop forcing progress and record `casual progression stall — City N`.

Also stop if the run reaches about **3 hours of active foreground play** before City 15 and record `campaign active-time budget exceeded — City N`.

These thresholds are validation guardrails, not proposed production timers.

A progression stall/time-budget stop is a **valid product outcome**, not an invalid test. Do not start expert optimization just to satisfy the City 15 checklist.

### Casual behavior contract

For each unlocked city:

1. Read the Scout Card before entry.
2. Enter through the normal map action.
3. Use Building View when it looks useful; do not open it on a forced schedule.
4. Consider Recommended Camp when visible; follow it when it feels sensible, otherwise use manual building naturally.
5. Fight in the normal Battle Scene.
6. Use Default Spawn/manual spawning when it feels naturally useful; do not maintain an expert cadence solely to speed the test.
7. Read the conquest report before continuing.
8. Record the city row immediately after conquest/return to map.

Do not inspect source, formulas, tests, or hidden state between cities to choose the next action.

### City-by-city log

```markdown
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

For `Friction`, use `none`, `confusion`, `repetition`, `boredom`, `attention`, or a combination when two distinct problems occurred. Do not use numeric ratings.

### Deep checkpoints — Cities 1, 5, 10, 15

At each checkpoint record:

```markdown
### Deep checkpoint — City <N>

- Clarity: <concrete observation>
- Repetition: <concrete observation>
- Battle engagement: <pleasantly passive / meaninglessly passive / appropriately active, with reason>
- Attention cost: <concrete observation>
- Reward and memory: <concrete observation>
- History demand: <concrete observation>
```

At Cities 5/10/15 also record whether milestone presentation still adds meaningful weight.

At City 15, add whether the finale feels like a meaningful campaign ending.

### One mandatory overnight idle window

HPA-567 must deliberately exercise the core idle loop once; leaving it to chance would under-test the product.

After City 5 and before the run ends, choose the **first suitable active city** where:

- the city is not yet conquered;
- at least one building exists;
- the tester is ready to stop active play for the session.

Background Pyxis for **at least 8 hours**, then return normally. Do not inject time or edit state.

Record:

```markdown
### Deliberate idle checkpoint — City <N>

- Before leaving: <what progress/state felt like>
- Return feedback: <was the result legible and understandable?>
- Reward value: <did the idle progress feel worthwhile?>
- Next action: <was it obvious what to do next?>
- Pressure: <did the system encourage healthy passive play or unwanted timer watching?>
```

If a city reaches the 20-minute checkpoint before this idle check has happened, use that city for the overnight window when it has at least one building. The 30-minute active cap excludes the overnight wait.

### Settings check

Exercise the existing Settings surface once at a non-critical moment. Sound Effects are in scope. Haptics may be toggled only as a UI/persistence control if desired; **do not evaluate tactile output on Simulator**.

### Completed-city history baseline

On the completed map, only treat **spontaneous** attempts/desire to inspect old cities as Chronicle evidence. If the tester naturally taps one, remember that the current shipping behavior is only the short `"<city> complete"` transient.

Do not manufacture history demand by systematically tapping completed cities.

---

## 3. Durability — preserve notes and the expensive campaign state

At Cities **1, 5, and 10**:

1. Paste the current run metadata, rows, and completed deep checkpoints into HPA-567 as a Linear comment headed `Working checkpoint — after City N`. Mark it clearly as partial evidence, not a conclusion.
2. On Simulator, snapshot the current app preference domain as recovery insurance.

The known durable Pyxis state is stored in app-container `UserDefaults`, so the checkpoint can copy the current preferences plist without adding production code.

Example after terminating Pyxis:

```bash
BUNDLE=cwchanap.Pyxis
BACKUP_DIR="$HOME/Desktop/pyxis-hpa-567-backups"
mkdir -p "$BACKUP_DIR"
xcrun simctl terminate booted "$BUNDLE" || true
CONTAINER="$(xcrun simctl get_app_container booted "$BUNDLE" data)"
cp "$CONTAINER/Library/Preferences/$BUNDLE.plist" "$BACKUP_DIR/city-<N>.plist"
plutil -p "$BACKUP_DIR/city-<N>.plist" | grep -q 'pyxis.kingdomGameState'
```

Then relaunch the same runtime baseline and continue.

### Recovery rule

Restoring **the tester's own unedited checkpoint** after accidental container loss is allowed. Fabricating, editing, fast-forwarding, or combining save state is not.

Recovery procedure:

1. Reinstall the same recorded runtime baseline if necessary.
2. Terminate Pyxis.
3. Resolve the new app data container with `simctl get_app_container`.
4. Copy the chosen checkpoint plist back to `Library/Preferences/cwchanap.Pyxis.plist`.
5. Shut down and boot that Simulator before relaunching so preferences are reloaded.
6. Verify the visible city/gold/building state matches the recorded checkpoint before continuing.
7. Record in HPA-567 that a checkpoint restore occurred.

If the restored state does not visibly match the checkpoint, do **not** continue from it. Keep the partial evidence and apply the early-termination rules below instead.

---

## 4. Early termination — partial runs remain useful

A run may end before City 15 for two different reasons.

### A. Product progression stall / active-time budget exceeded

This is a valid terminal HPA-567 product result. Record:

- last city reached;
- approximate active foreground time;
- whether the mandatory idle checkpoint had occurred and what it changed;
- what a casual player would have needed to do to continue;
- why continuing would have required tester obligation or expert optimization.

The finding `campaign not completable under the casual contract` is publishable evidence.

### B. Functional blocker

For a crash, broken route, build failure, persistence failure, or other functional defect:

- publish the partial evidence already collected;
- file the blocker separately with reproduction details;
- do not treat the blocker itself as evidence for a new mechanic;
- HPA-567 remains open until the blocker is resolved and the missing product journey can be validated.

### What decisions may come from a partial run?

- **PROTOTYPE / ACTIVATE** may be chosen from a partial run when repeated evidence already identifies the problem and the proposed item is clearly the smallest fit.
- **KEEP DEFERRED** may be chosen from a partial run when evidence is missing/inconclusive or the problem exists but the proposed item is not clearly the right fit.
- **DROP requires a complete City 1 -> City 15 run.** Absence of a problem cannot be claimed for unseen cities.

Do not discard useful Cities 1-N evidence merely because City N+1 was not reached.

---

## 5. Decisions — solve observed problems, not architectural opportunity

First write the campaign/partial-run synthesis:

```markdown
### Synthesis

- Clarity: <dominant pattern + examples>
- Repetition: <dominant pattern + examples>
- Battle engagement: <dominant pattern + examples>
- Attention cost: <dominant pattern + examples>
- Reward and memory: <dominant pattern + examples>
- History demand: <dominant pattern + examples>
- Progression/time burden: <complete / stalled, with context>
- Idle loop: <what the deliberate overnight window showed>
```

Separate functional bugs/polish before making feature decisions.

### Shared outcomes

- **PROTOTYPE / ACTIVATE MINIMAL IMPLEMENTATION** — repeated evidence shows an unmet problem and this item is the clearest small fit.
- **KEEP DEFERRED** — evidence is missing/inconclusive, or the problem is real but this item is not clearly the right fit.
- **DROP** — only after a complete run, the relevant problem class is absent or shipping UX already covers the value well enough.

### HPA-362 — direct lane deployment

Choose `PROTOTYPE`, `KEEP DEFERRED`, or, after a complete run only, `DROP`.

Prototype only when the tester repeatedly wants to choose **which visible battlefield lane receives a manual soldier**.

Interpret current information correctly:

- Scout exposes only the **exposed lane**;
- Battle shows all three physical lanes;
- Scout does not explain the full fortified/exposed/standard role set.

Missing fortified/standard explanation is **clarity/presentation evidence**, not automatic evidence for direct lane placement.

### HPA-369 — Rally

Choose `PROTOTYPE`, `KEEP DEFERRED`, or, after a complete run only, `DROP`.

Prototype only when battles are understandable but repeatedly feel emotionally flat and one obvious active moment would help **without** ongoing micromanagement or attention pressure.

Do not activate Rally merely because battles take time.

### HPA-367 — Campaign Chronicle

Choose `ACTIVATE MINIMAL IMPLEMENTATION`, `KEEP DEFERRED`, or, after a complete run only, `DROP`.

Activate only when the tester naturally wants completed-city history and the current completion-only transient feels materially insufficient.

Enjoying conquest reports alone is not evidence for Chronicle persistence.

### Battle experiment conflict rule

Do not prototype HPA-362 and HPA-369 together by default. If both appear supported, choose the one that addresses the clearer repeated problem. Keep the other deferred unless the evidence shows two genuinely distinct unmet needs.

For each downstream issue write:

```markdown
## HPA-567 decision

**Decision:** <Prototype | Activate minimal implementation | Keep deferred | Drop>

**Evidence:** <specific observed behavior>

**Fit:** <why this item specifically is or is not the right response>

**Next action:** <prototype/activate | leave in Backlog | close/drop>
```

---

## 6. Publishing and completion

### HPA-567 result

Publish one canonical result comment containing:

1. baseline metadata;
2. City 1-N table;
3. available City 1/5/10/15 deep checkpoints;
4. deliberate idle checkpoint when reached;
5. synthesis including progression/time burden;
6. separately tracked blockers/polish;
7. HPA-362/HPA-369/HPA-367 decisions.

Earlier City 1/5/10 comments remain durability snapshots only.

### Separate bugs/polish

File concrete functional problems separately with:

- commit/simulator;
- city/context;
- reproduction;
- expected behavior;
- observed behavior.

Do not fix them inside HPA-567.

### HPA-360

Update HPA-360 only when HPA-567 changes roadmap priorities. A validation that confirms existing deferral does not need a roadmap rewrite.

### Completion rule

HPA-567 may be completed when either:

1. **Full campaign:** City 1 -> 15 is recorded, including the deliberate idle checkpoint and explicit downstream decisions; or
2. **Validated progression stop:** the run terminates under the 30-minute city cap or ~3-hour active campaign budget and clearly records that the casual contract could not complete Country 1.

A functional blocker does not by itself satisfy completion; preserve the partial evidence, fix/resolve the blocker separately, then continue/re-run the missing journey.

Before completion verify only these essentials:

```text
[ ] Baseline commit/simulator/iOS recorded.
[ ] Per-city rows exist through the final reached city.
[ ] Required deep checkpoints reached so far are recorded.
[ ] One deliberate 8h+ idle window was exercised unless a blocker or validated progression stop ended the run before a suitable city existed.
[ ] Progression stall/time-budget findings are preserved rather than optimized away.
[ ] HPA-362/HPA-369/HPA-367 each have an evidence-backed decision allowed by full/partial-run rules.
[ ] Bugs/polish are separate issues.
[ ] No production/test/project files changed for HPA-567 execution.
```
