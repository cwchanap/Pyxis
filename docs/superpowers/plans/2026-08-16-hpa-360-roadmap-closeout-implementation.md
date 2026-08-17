# HPA-360 Roadmap Closeout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close HPA-360 at the already-shipped Country 1 enrichment scope while preserving the canceled HPA-567 validation record and keeping HPA-362, HPA-369, and HPA-367 evidence-gated in Backlog.

**Architecture:** This is a Linear-only roadmap metadata change. No runtime or repository architecture changes. HPA-360 becomes the single closeout record; HPA-567 keeps the failed-cost validation history; each deferred child keeps its existing start gate and blocker relation.

**Tech Stack:** Linear issue metadata/comments; GitHub planning documents only.

## Global Constraints

- Do not change production code, tests, assets, persistence, Xcode project files, CI, or runtime behavior.
- Do not reopen HPA-567 as part of this work.
- Do not move HPA-362, HPA-369, or HPA-367 out of Backlog.
- Do not record `Prototype`, `Activate`, `Ship`, `Revise`, or `Drop` for any deferred child; no supporting product evidence exists.
- Do not treat HPA-618 DEBUG jump testing as casual-friction evidence.
- Do not create a replacement playtest harness, telemetry system, scoring system, or new gameplay issue to make the roadmap appear active.
- Preserve HPA-360's existing Goal, Product principles, Delivery contract, Product gates, and historical delivered-baseline information unless the exact stale execution wording described below conflicts with the closeout.

---

## File / issue map

**Repository planning artifacts created by the planning PR:**

- `docs/superpowers/specs/2026-08-16-hpa-360-roadmap-closeout-design.md` — decision, scope, alternatives, and future-work contract.
- `docs/superpowers/plans/2026-08-16-hpa-360-roadmap-closeout-implementation.md` — this Linear execution checklist.

**Linear entities executed by this plan:**

- Modify: `HPA-360` description, add one final comment, then move to Done.
- Verify only: `HPA-567`, `HPA-362`, `HPA-369`, `HPA-367`.
- Verify only: completed committed slices `HPA-366`, `HPA-365`, `HPA-390`.

There are no source-code interfaces and no runtime test surface for this plan.

---

### Task 1: Re-verify the closeout preconditions

**Linear issues:**
- Read: `HPA-360`
- Read: `HPA-567`
- Read: `HPA-366`
- Read: `HPA-365`
- Read: `HPA-390`
- Read: `HPA-362`
- Read: `HPA-369`
- Read: `HPA-367`

**Interfaces:**
- Consumes: current Linear statuses, descriptions, relations, and HPA-567 cancellation rationale.
- Produces: a yes/no decision that the roadmap can be closed without activating new scope.

- [ ] **Step 1: Fetch HPA-360 and the validation issue with relations**

Use:

```text
Linear.get_issue(id: "HPA-360", includeRelations: true)
Linear.get_issue(id: "HPA-567", includeRelations: true)
Linear.list_comments(issueId: "HPA-567")
```

Expected facts:

- `HPA-360` is still Backlog.
- `HPA-567` is Canceled, not Done.
- HPA-567's final comment states the human validation methodology was too expensive, the partial run contains no subjective friction evidence, and HPA-362/HPA-369/HPA-367 remain deferred.

- [ ] **Step 2: Verify the committed player-visible sequence is complete**

Use:

```text
Linear.get_issue(id: "HPA-366")
Linear.get_issue(id: "HPA-365")
Linear.get_issue(id: "HPA-390")
```

Expected: all three have status type `completed` / status `Done`.

If any is not completed, stop this plan. The closeout premise is false.

- [ ] **Step 3: Verify every deferred child still has the evidence gate**

Use:

```text
Linear.get_issue(id: "HPA-362", includeRelations: true)
Linear.get_issue(id: "HPA-369", includeRelations: true)
Linear.get_issue(id: "HPA-367", includeRelations: true)
```

Expected:

- all three remain Backlog;
- HPA-362 says to start only after playtest evidence that battles need another tactical choice;
- HPA-369 says to start only after validation records a need for one active emotional moment;
- HPA-367 says to reconsider only after concrete completed-city history demand;
- HPA-567 remains a blocker relation for each relevant issue.

Do not mutate these issues in Task 1.

- [ ] **Step 4: Record the precondition result before editing**

The execution worker's task note should state exactly:

```text
Closeout preconditions satisfied: HPA-366/HPA-365/HPA-390 are complete; HPA-567 is canceled for methodology cost with no qualifying product evidence; HPA-362/HPA-369/HPA-367 remain evidence-gated Backlog items.
```

Do not proceed if any clause is false.

---

### Task 2: Rewrite HPA-360 from active queue to bounded closeout

**Linear issue:**
- Modify: `HPA-360`

**Interfaces:**
- Consumes: the existing HPA-360 description plus the verified Task 1 facts.
- Produces: a roadmap description that preserves project principles and history while making the current completion state explicit.

- [ ] **Step 1: Preserve the stable roadmap sections verbatim**

From the current HPA-360 description, retain these sections and their substantive rules:

```text
## Goal
## Product principles
## Delivery contract
## Delivered baseline — keep closed and freeze scope
## Product gates
```

Do not weaken the evidence-gate, current-consumer-only, behavior-oriented-testing, or complexity-review rules.

- [ ] **Step 2: Replace `## Active player-visible sequence` with this closeout section**

Use this exact Markdown content:

```markdown
## Delivered Country 1 enrichment

The committed low-complexity player-value sequence is complete:

1. **HPA-366 — city identity** — shipped authored Country 1 names, flavor, and conquest identity through existing surfaces without new gameplay or persistence.
2. **HPA-365 — Recommended Camp** — shipped one deterministic explicit preparation suggestion through the existing Building View mutation path without an optimizer platform.
3. **HPA-390 — milestone presentation** — shipped presentation-only treatment for Cities 5, 10, and 15 without combat, economy, reward, or persistent milestone-state changes.

These three slices are the completed active scope of this roadmap. Do not reopen or expand them to create work for deferred hypotheses.
```

- [ ] **Step 3: Replace `## Campaign validation checkpoint` with this deferred-evidence section**

Use this exact Markdown content:

```markdown
## Deferred evidence gate

HPA-567 attempted the planned City 1→15 casual-player validation and was canceled on August 13, 2026 because its strict human methodology — roughly 1–3 hours of foreground play plus an 8-hour idle window, without automation or state fabrication — was not affordable under current constraints.

The cancellation is **not** a successful validation result. Its preserved partial City 1 run contains no subjective casual-friction evidence and therefore does not justify a new mechanic or durable campaign subsystem.

HPA-618's DEBUG-only jump-to-city tool may be used for developer smoke testing, but it does not reproduce normal progression, repetition, attention cost, or casual decision-making and must not be treated as a substitute for HPA-567 evidence.

Until new human evidence exists:

- **HPA-362 — direct lane deployment** remains Backlog. Start only for repeated observed desire to choose a visible battlefield lane or a clearly documented need for one additional tactical choice.
- **HPA-369 — Rally** remains Backlog. Start only when battles are understandable but repeatedly feel emotionally flat and one optional active moment is supported by actual play evidence.
- **HPA-367 — Campaign Chronicle** remains Backlog/deferred. Start only for concrete completed-city history demand beyond the current completion feedback.

Closing HPA-360 does not mark these hypotheses as `ship`, `drop`, `prototype`, or `activate`. It records that no additional scope is justified today. Future evidence may reactivate one item without reopening the entire roadmap.
```

- [ ] **Step 4: Replace `## Deferred or removed` with a compact closeout version**

Use this exact Markdown content:

```markdown
## Deferred or removed

- **HPA-362** — evidence-gated direct lane deployment experiment; remains Backlog.
- **HPA-369** — evidence-gated in-memory Rally experiment; remains Backlog.
- **HPA-367** — Campaign Chronicle; remains deferred until actual completed-city history demand exists.
- **HPA-368** — persistent collectible accolades remain canceled under Option C.
- **HPA-567** — casual City 1→15 validation remains canceled for methodology cost; its partial evidence does not support child activation.
- **HPA-566** — deletion-first gameplay-feedback simplification is already complete; do not reopen it as general cleanup.

Do not replace any deferred item with a new framework, mechanic, telemetry system, or cheaper-but-non-equivalent validation surrogate merely to continue the roadmap.
```

- [ ] **Step 5: Replace `## Roadmap completion criteria` with the bounded completion contract**

Use this exact Markdown content:

```markdown
## Roadmap completion criteria

HPA-360 is complete when:

- HPA-366, HPA-365, and HPA-390 are shipped as compact player-visible slices.
- The canceled HPA-567 attempt and its methodology-cost rationale remain recorded without being misrepresented as a successful playtest.
- HPA-362, HPA-369, and HPA-367 remain unactivated in the absence of their required human evidence.
- The number of systems a casual player must manage has not increased beyond the shipped Country 1 baseline.
- New code remains proportionate to demonstrated player value and the repository is not expanded merely to satisfy a roadmap queue.

Future player evidence can create a new bounded slice or reactivate one deferred hypothesis. It does not make this completed roadmap retroactively incomplete.
```

- [ ] **Step 6: Save the complete HPA-360 description in one update**

Use one `Linear.save_issue(id: "HPA-360", description: <complete merged description>)` call so the issue never temporarily contains a partial roadmap.

Do **not** change HPA-360 status in this step.

- [ ] **Step 7: Re-fetch HPA-360 and perform a text self-review**

Check all of the following in the returned description:

```text
Contains: "Delivered Country 1 enrichment"
Contains: "Deferred evidence gate"
Contains: "HPA-567" and "canceled"
Contains: "HPA-618" and the statement that DEBUG jump testing is not substitute casual evidence
Contains: HPA-362, HPA-369, HPA-367 as Backlog/deferred
Does not claim HPA-567 completed a City 1→15 validation
Does not assign Prototype/Activate/Drop/Ship decisions to deferred children
Does not add any new gameplay commitment
```

Fix the description before Task 3 if any check fails.

---

### Task 3: Close HPA-360 without changing deferred child states

**Linear issues:**
- Modify: `HPA-360`
- Verify only: `HPA-567`, `HPA-362`, `HPA-369`, `HPA-367`

**Interfaces:**
- Consumes: the self-reviewed HPA-360 description from Task 2.
- Produces: HPA-360 in Done with an auditable closeout comment and unchanged deferred children.

- [ ] **Step 1: Add the final HPA-360 closeout comment**

Post this comment, inserting the actual planning PR URL where shown:

```markdown
## Roadmap closeout — August 16, 2026

The committed HPA-360 Country 1 enrichment sequence is complete: HPA-366, HPA-365, and HPA-390 are shipped.

HPA-567's casual City 1→15 validation was attempted and canceled for methodology cost. Its partial run contains no qualifying subjective friction evidence, so this closeout does not manufacture a validation pass or activate downstream hypotheses.

Decision:

- HPA-360 closes at the shipped baseline.
- HPA-567 remains Canceled.
- HPA-362 and HPA-369 remain evidence-gated Backlog experiments.
- HPA-367 remains deferred until concrete completed-city history demand exists.
- HPA-618 DEBUG jump testing remains developer smoke only and is not a substitute evidence source.

Future player evidence can reopen/re-scope validation or activate one bounded hypothesis directly; it does not require keeping this roadmap permanently open.

Planning: <PLANNING_PR_URL>
```

- [ ] **Step 2: Move only HPA-360 to Done**

Use:

```text
Linear.save_issue(id: "HPA-360", state: "Done")
```

Do not mutate HPA-567, HPA-362, HPA-369, or HPA-367.

- [ ] **Step 3: Verify the final Linear state**

Fetch all five issues and confirm:

```text
HPA-360: Done
HPA-567: Canceled
HPA-362: Backlog
HPA-369: Backlog
HPA-367: Backlog
```

Also confirm HPA-362/HPA-369/HPA-367 still retain their HPA-567 blocker relation where it existed before execution.

- [ ] **Step 4: Verify repository scope stayed documentation-only**

Inspect the planning PR changed files.

Expected exactly:

```text
docs/superpowers/specs/2026-08-16-hpa-360-roadmap-closeout-design.md
docs/superpowers/plans/2026-08-16-hpa-360-roadmap-closeout-implementation.md
```

No Swift, test, asset, project, workflow, or configuration file belongs in this work.

- [ ] **Step 5: Record completion evidence**

The final execution summary must state:

```text
HPA-360 closed at shipped scope; HPA-567 remains canceled; HPA-362/HPA-369/HPA-367 remain deferred Backlog items; no runtime or repository behavior changed.
```

That is the complete implementation. Do not create a follow-up gameplay ticket automatically.